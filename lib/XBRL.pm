package XBRL;

#use strict;
use warnings;

use Carp;
use XML::LibXML; 
use XML::LibXML::XPathContext; 
use XBRL::Context;
use XBRL::Unit;
use XBRL::Item;
use XBRL::Schema;
use XBRL::Taxonomy;
use XBRL::Dimension;
use XBRL::Table;

use LWP::UserAgent;
use File::Spec qw( splitpath catpath curdir);
use File::Temp qw(tempdir);
use Cwd;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';
our $agent_string = "Perl XBRL Library $VERSION";



sub new() {
	my ($class, $arg_ref ) = @_;
	
	my $self = { contexts => {},
								units => {},
								items => {},
								schemas => {},
								main_schema => undef,	
								linkbases => {},
								item_index => undef,
								file => undef,
								schema_dir => undef, 
								base => undef };
	
	bless $self, $class;

	$self->{'schema_dir'} =  $arg_ref->{'schema_dir'};
	$self->{'file'} = $arg_ref->{'file'};

	#Check the schema dir 
	if ($self->{'schema_dir'}) {
		if (-d $self->{'schema_dir'} )  { 
			if ( ! -w $self->{'schema_dir'} ) {
			#the directory exits but isn't writeable 
			croak "$self->{'schema_dir'} exists but isn't writeable by this user\n";	
			}	
		}	
		else {
			#try and create the directory 
			mkdir($self->{'schema_dir'}, 777) or croak $self->{'schema_dir'} . " can't be created because: $!\n";
		}
	}
	else {
		#the schema_dir parameter wasn't there, use tmp 
		$self->{'schema_dir'} = File::Temp->newdir(); 
	}

	my ($volume, $dir, $filename);

	if ($self->{'file'}) { 
		($volume, $dir, $filename) = File::Spec->splitpath( $self->{'file'});
		if (! $dir) {
						#croak "no directory in the file path \n";
						#my $curdir = File::Spec->curdir();	
			my $curdir = getcwd(); 
		  my $full_path = File::Spec->catpath( undef, $curdir, $self->{'file'} );	
			if (-e $full_path) {
				$self->{'base'} = $curdir;
				$self->{'fullpath'} = $full_path;	
			}	
			else {
				croak "can't find $full_path to start processing\n";
			}	
		}	
		else {
			$self->{'fullpath'} = $self->{'file'};	
			$self->{'file'} = $filename;
			$self->{'base'} = $dir;	
		}	
	}
 	else {
		croak "XBRL requires an existing file to begin processing\n"; 
	}	
	
	&parse_file( $self ); 

	return $self;
}

sub parse_file() {
	my ($self) = @_;

	if (!$self->{'fullpath'}) {
		croak "full path not set in parse file but file is set to: $self->{'file'} \n";
	}


	my $xc 	= &make_xpath($self, $self->{'fullpath'}); 

	#unless($xc)  { croak "Couldn't parse $file \n" };
	
	my $ns = &extract_namespaces($self, $self->{'fullpath'}); 

	#load the schemas 
	my $s_ref = $xc->findnodes("//*[local-name() = 'schemaRef']");
	my $schema_file = $s_ref->[0]->getAttribute('xlink:href');
	my $schema_xpath = &make_xpath($self, $schema_file);
	my $main_schema = XBRL::Schema->new( { file=> $schema_file, xpath=>$schema_xpath });
	
	$self->{'taxonomy'} = XBRL::Taxonomy->new( {main_schema => $main_schema} ); 
	
	my $other_schema_files = $self->{'taxonomy'}->get_other_schemas();	
		
	for my $other (@{$other_schema_files}) {
		#Get the file 
		my $s_file = &get_file($self, $other, $self->{'schema_dir'}); 
		#make the xpath 
		my $s_xpath = &make_xpath($self, $s_file);	
		#add the schema   
		my $schema = XBRL::Schema->new( { file => $s_file, xpath=>$s_xpath } );	
		$self->{'taxonomy'}->add_schema($schema);	
	}


	my $lb_files = $self->{'taxonomy'}->get_lb_files();	

	for my $file_name (@{$lb_files}) {
		my $file = &get_file($self, $file_name, $self->{'base'}); 
		if (!$file) {
			print "The basedir is: " . $self->{'basedir'} . "\n"; 	
			croak "unable to get $file_name\n";
	}	
		
		my $lb_xpath = &make_xpath($self, $file);
		
		if ($lb_xpath->findnodes("//*[local-name() = 'presentationLink']") ){ 
			$self->{'taxonomy'}->pre($lb_xpath);	
		}
		elsif ( $lb_xpath->findnodes("//*[local-name() = 'definitionLink']" )) {	 
			$self->{'taxonomy'}->def($lb_xpath);	
		}
		elsif ( $lb_xpath->findnodes("//*[local-name() = 'labelLink']")) { 	 
			$self->{'taxonomy'}->lab($lb_xpath);	
			$self->{'taxonomy'}->set_labels();	
		}
		elsif ( $lb_xpath->findnodes("//*[local-name() = 'calculationLink']") ) { 	 
			$self->{'taxonomy'}->cal($lb_xpath);	
		}
	
	}



	#load the contexts 
	my $cons = $xc->findnodes("//*[local-name() = 'context']");
	for (@$cons) {
		my $cont = XBRL::Context->new($_); 	
		$self->{'contexts'}->{ $cont->id() } = $cont;	
	}

	#parse the units 	
	my $units = $xc->findnodes("//*[local-name() =  'unit']");
	for (@$units) {
		my $unit = XBRL::Unit->new($_); 	
		$self->{'units'}->{ $unit->id() } = $unit;	
	}

	#load the items	
	my $raw_items = $xc->findnodes('//*[@contextRef]');
	my @items = ();
	for my $instance_xml (@$raw_items) {
		
		my $item = XBRL::Item->new($instance_xml);	
		push(@items, $item);	
	}
	$self->{'items'} = \@items;

	#create the item lookup index	
	my %index = ();
	for (my $j = 0; $j < @items; $j++) {
		$index{$items[$j]->name()}{$items[$j]->context()} = $j; 
	}
	$self->{'item_index'} = \%index;
}


sub get_taxonomy() {
	my ($self) = @_;
	return $self->{'taxonomy'};
}

sub get_context() {
	my ($self, $id) = @_;
	return($self->{'contexts'}->{$id});
}

sub get_all_contexts() {
	my ($self) = @_;
	return($self->{'contexts'}); 
}

sub get_unit() {
	my ($self, $id) = @_;
	return($self->{'units'}->{$id});
}

sub get_item() {
	my ($self, $name, $context) = @_;
	my $item_number = $self->{'item_index'}->{$name}->{$context}; 
	unless (defined($item_number)) { $item_number = -1; } 	
	return($self->{'items'}[$item_number]); 
}

sub get_all_items() {
	my ($self) = @_;
	return($self->{'items'});
}


sub get_item_all_contexts() {
	my ($self, $name) = @_; 
	my @item_array = ();
	for (keys %{$self->{'item_index'}->{$name}}) {
		my $item_number = $self->{'item_index'}->{$name}->{$_};
		push(@item_array, $self->{'items'}[$item_number]);  
	}
	return \@item_array;	
}


sub get_item_by_contexts() {
	my ($self, $search_context) = @_;
	my @out_array = ();

	for my $item (@{$self->{'items'}}) {
		if ($item->context() eq $search_context) {
			push(@out_array, $item);
		}
	}
	return \@out_array;
}

sub make_xpath() {
	#take a file path and return an xpath context
	my ($self, $in_file) = @_;
	my $ns = &extract_namespaces($self, $in_file); 

	my $xml_doc =XML::LibXML->load_xml( location => $in_file); 


	my $xml_xpath = XML::LibXML::XPathContext->new($xml_doc);


	for (keys %{$ns}) {
		$xml_xpath->registerNs($_, $ns->{$_});
	}
	
	return $xml_xpath;
}

sub extract_namespaces() {
	#take an xml string and return an hash ref with name and 
	#urls for all the namespaces 
	my ($self, $xml) = @_; 
	my %out_hash = ();
	my $parser = XML::LibXML->new();
	my $doc = $parser->load_xml( location => $xml );

	my $root = $doc->documentElement();

	my @ns = $root->getNamespaces();
	for (@ns) {
		my $localname = $_->getLocalName();
		if (!$localname) {
			$out_hash{'default'} = $_->getData();
		}
		else {	
			$out_hash{$localname} = $_->getData();	
		}	
	}
	return \%out_hash;
}

sub get_file() {
	my ( $self, $in_file, $dest_dir ) = @_;
	
	if ($in_file =~ m/^http\:\/\//) {
		$in_file =~ m/^http\:\/\/[a-zA-Z0-9\/].+\/(.*)$/;
		my $full_path = File::Spec->catpath(undef, $dest_dir, $1);	
		if ( -e $full_path) {
			return $full_path;
		}
	
		$full_path = File::Spec->catpath(undef, $self->{'schema_dir'}, $1);	

		if ( -e $full_path) {
			return $full_path;
		}
		else {
			my $ua = LWP::UserAgent->new();
			$ua->agent($agent_string);
			my $response = $ua->get($in_file);
			if ($response->is_success) {
				my $fh;	
				open($fh, ">$full_path") or croak "can't open $full_path because: $! \n";
				print $fh $response->content;	
				close $fh;	
				return $full_path;	
			}	
			else {
				croak "Unable to retrieve $in_file because: " . $response->status_line . "\n"; 
			}	
		}
	}
	else {
		#process regular file 
		my ($volume, $dir, $filename) = File::Spec->splitpath( $in_file );
			
		if ( ($dir) && (-e $in_file) ) {
			return $in_file;
		}	
		
		my $test_path = File::Spec->catpath(undef, $self->{'base'}, $filename);	
			
		if ( -e $test_path) {
			return $test_path;
		}	
		
		$test_path = File::Spec->catpath(undef, $self->{'schema_dir'}, $filename);	
		if ( -e $test_path) {
			return $test_path;
		}		
	}
}


sub get_html_report() {
	my ($self) = @_;
	my $html = "<html><head><title>Sample</title></head><body>\n";

	my $tax = $self->{'taxonomy'}; 

	my $sections = $tax->get_sections();
		
	for my $sect (@{$sections}) {
		if ($tax->in_def($sect->{'uri'})) {
			#Dimension table 	
			$html = $html . "\n<h2>" . $sect->{'def'} . "</h2>\n";
			my $dim = XBRL::Dimension->new($self, $sect->{'uri'});	
			my $final_table;	
			$final_table = $dim->get_html_table($sect->{'uri'}); 	
		
			if ($final_table) {	
				$html = $html . $final_table;	
			}	
		}
		else {
			#Dealing with a regular table 
			#if (&is_text_block($self, $sect->{'uri'})) {
			my $norm_table = XBRL::Table->new($self); 
			$html = $html . "\n<h2>" . $sect->{'def'} . "</h2>\n";
			$html = $html . $norm_table->get_html_table($sect->{'uri'});
		}
	}
	
	$html = $html . "</body></html>\n";

}




1;

__END__

=head1 NAME

XBRL - Perl extension for Reading Extensible Business Reporting Language documents 

=head1 CAVEAT UTILITOR

The Extensible Business Reporting Language (XBRL) is a large and complex standard 
and this module only partially supports the standard.  
 
=head1 SYNOPSIS

use XBRL;

my $xbrl_doc = XBRL->new( {file=>"foo.xml", schema_dir="/var/cache/xbrl"});

my $html_report = $doc->get_html_report();


=head1 DESCRIPTION

XBRL provides an OO interface for reading Extensible Business Reporting Language
documents (XBRL docs).  

new()
	$xbrl_doc = XBRL->new ( { file="foo.xml", schema_dir="/var/cache/xbrl" } );

	file -- This option specifies the main XBRL doc instance.

	schema_dir -- allows the caller to specify a directory for storing ancillary
	schemas required by the instance.  Specifying this directory means 
	those schemas won't have to be downloaded each time an XBRL doc is 
	parsed.  If no schema_dir is specified, the module will create a temporary
	directory to store any needed schemas and delete it when the module goes 
	out of scope.

get_html_report()
	$html = $xbrl_doc->get_html_report() 
	Processes the XBRL doc into an HTML document.  

get_item_by_contexts($context_id) 
	Return an array reference of XBRL::Items which share the same context.

get_item_all_contexts($item_name) 
	Takes an item name and returns an array reference of all other items with the 
	same name. 

get_all_items() 
	Returns an array reference to the list of all items.

get_item($item_name, $context_id) 
	Returns an item identified by the its name and context.  Undef if no item 
	of that description exists.

get_unit($id) 
	Returns unit identified by its id. 

get_all_contexts()
	Returns a hash reference  where the keys are the context ids and the values are
	XBRL::Context objects. 
  
get_context($id)
	Returns an XBRL::Context object based on the ID passed into the function.
	
get_taxonomy()
	Returns an XBRL::Taxonomy instance based on the XBRL document. 


=head1 BUGS AND LIMITATIONS 

There are a gajillion bugs. This module only partially supports the XBRL
standard and won't currently work on Windows systems. 
	
=head1 SEE ALSO

Source code, documentation, and bug tracking is hosted 
at: https://github.com/MarkGannon/XBRL . 

=head1 AUTHOR

Mark Gannon <mark@truenorth.nu>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Mark Gannon 

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10 or,
at your option, any later version of Perl 5 you may have available.


=cut
