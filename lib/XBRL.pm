package XBRL;

use strict;
use warnings;

use Data::Dumper;
use Carp;
use XML::LibXML; 
use XML::LibXML::XPathContext; 
use XBRL::Context;
use XBRL::Unit;
use XBRL::Item;
use XBRL::Schema;
use XBRL::Taxonomy;
use LWP::UserAgent;
use File::Spec qw( splitpath );


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
	my ($class, $file) = @_;
	my $self = { contexts => {},
								units => {},
								items => {},
								schemas => {},
								main_schema => undef,	
								linkbases => {},
								item_index => undef,
								file => $file,
								base => undef };
	bless $self, $class;
	
	my ($volume, $dir, $filename);

	if ($file !~ m/^http\:\/\//) {
		($volume, $dir, $filename) = File::Spec->splitpath( $file );
		$self->{'base'} = $dir;	
	}
  
	$self->{'file'} = &get_file($self, $file);
	
	&parse_file( $self, $file );

	return $self;
}

sub parse_file() {
	my ($self, $file) = @_;

	#if (! -e $file) { croak "$file doesn't exist\n" };

	my $xc 	= &make_xpath($self, $file); 

	unless($xc)  { croak "Couldn't parse $file \n" };

	#load the schemas 
	my $s_ref = $xc->findnodes('//link:schemaRef');
	my $schema_file = $s_ref->[0]->getAttribute('xlink:href');

	$self->{'taxonomy'} = XBRL::Taxonomy->new( $schema_file );

	#load the contexts 
	my $cons = $xc->findnodes('//xbrli:context');
	for (@$cons) {
		my $cont = XBRL::Context->new($_); 	
		$self->{'contexts'}->{ $cont->id() } = $cont;	
	}

	#parse the units 	
	my $units = $xc->findnodes('//xbrli:unit');
	for (@$units) {
		my $unit = XBRL::Unit->new($_); 	
		$self->{'units'}->{ $unit->id() } = $unit;	
	}

	#load the items	
	my $raw_items = $xc->findnodes('//*[@contextRef]');
	my @items = ();
	for my $instance_xml (@$raw_items) {
		
		my $item = XBRL::Item->new($instance_xml);	
		&set_label($self, $item); 
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


sub set_label() {
	#takes an item and finds the correct label for it
	#via xpath search of the label linkbase
	my ($self, $item) = @_;
	#build a query string for this item 	
	my $ns = $item->namespace(); 
	#my $file = $self->{'schemas'}->{$ns}->file();
	my $file = $self->{'taxonomy'}->{'schemas'}->{$ns}->file();	
	my $lbl_string = $file . '#' . $item->prefix() . '_' . $item->localname();
	my $lab_lb = $self->{'taxonomy'}->lab(); 
	#query for the locator node 	
	my $loc_nodes = $lab_lb->findnodes("//*[\@xlink:href = '" . $lbl_string . "']");	
	#get the label 	
	my $label = $loc_nodes->[0]->getAttribute('xlink:label');
	#use the label to find the arc node 	
	my $arcs = $lab_lb->findnodes("//*[\@xlink:from = '" . $label . "']"); 
	#use the arc node to find the query parameter for the label node 	
	my $dest = $arcs->[0]->getAttribute('xlink:to');
	#query for the label nodes 	
	my $label_nodes = $lab_lb->findnodes("//*[\@xlink:label = '" . $dest . "' and \@xlink:role = 'http://www.xbrl.org/2003/role/label' ] ");	 
	#cycle through the results 	and set the value 
	for my $l_node (@$label_nodes) {		
				$item->label( $l_node->textContent());
	}


}


sub get_linkbases() {
	my ($self) = @_;
	my $lb =  $self->{'linkbases'}; 
	return $lb;	
}

sub get_schemas() {
	my ($self) = @_;
	my $schemas =  $self->{'schemas'}; 
	return $schemas;	
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
	
	if (! -e $in_file) {
		my $extended_file = &get_file($self, $in_file);	
		if ( ! -e $extended_file) {	
			croak "$in_file doesn't exist\n";
		}	
		else {
			$in_file = $extended_file;	
		}
	
	}
	
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


sub fix_item() {
	my ($self, $uri) = @_;
		$uri =~ m/\.xsd\#(.*)/;
		my $short_uri = $1;	
		$short_uri =~ s/_/\:/;
		return($short_uri);
}

sub get_file() {
	#manage the whole file thang.
	my ($self, $in_file) = @_;
	
	if ($in_file =~ m/^http\:\/\//) {
		$in_file =~ m/^http\:\/\/[a-zA-Z0-9\/].+\/(.*)$/;
		my $local_file = $1;
		if ( -e $local_file) {
			return $local_file;
		}
		else {
			my $ua = LWP::UserAgent->new();
			$ua->agent($agent_string);
			my $response = $ua->get($in_file);
			if ($response->is_success) {
				my $fh;	
				open($fh, ">$local_file") or croak "can't open $local_file because: $! \n";
				print $fh $response->content;	
				close $fh;	
				return $local_file;	
			}	

		}

	}

	if ( ! -e $in_file) {
		my $test_path;	
		if ($self->{'base'}) {
			$test_path = $self->{'base'} . $in_file;
			if ( -e $test_path) {
				return $test_path;
			}
			else {
				croak "Can't find $test_path\n";
			}
		}
	}
	else {
		return $in_file;
	}
}

sub expand_axis() {
	my ($self, $elements) = @_;
	my @out_array = ();
	
	my $all_contexts =  &get_all_contexts($self);

	for my $element (@{$elements}) {
			my $e_id = $element->id();
			$e_id =~ s/\_/\:/;	
			if ($element->subGroup() =~ m/dimensionItem/) {
				#Do the expansion 	
				for my $context_id (keys %{$all_contexts}) {
					my %seen = ();	
					my $context = &get_context($self, $context_id); 
					if ($context->is_dim_member($e_id)) {
						my $items = &get_item_by_contexts($self, $context->id()); 
						for my $item (@{$items}) {
							if (! $seen{$item->name()} ) {
								$seen{$item->name()}++;	
								my $item_id = $item->name();	
								$item_id =~ s/\:/\_/;	
								#print "$item_id \n";	
								my $element = $self->{'taxonomy'}->get_elementbyid($item_id);	
								if ($element) {	
									push(@out_array, $element); 
								}	
							}			
						}	
					}
				}
			}
			else {
				push(@out_array, $element);
			}	
	}
	return \@out_array;
}

sub report_html() {
	my ($self, $html_file) = @_;
	

	my $html = "<html><head><title>Test Doc</title></head><body>\n"; 

	my $sections = $self->{'taxonomy'}->get_sections();

	for (@$sections) {
#		my @table_rows = ();	
		my $def_node = $_->{'def'};	
		my $role_uri = $_->{'uri'};	
		print "$def_node \n";
		$self->{'taxonomy'}->debug_subsects($role_uri); 
#	
#		
#		$html = $html . '<h2>' . $def_node . '<h2>' . "\n";
#		
#		print "$def_node\n";   
#		
#		my $elements = &expand_axis($self, $self->{'taxonomy'}->get_pre_elems2($role_uri)); 
#
#		my @section_contexts;
#		my %section_labels = ();
#		my %rows = ();
#
#		my $t_headers = &get_table_headers($self, $elements);
#
#		my $table = '<table border="2">';	
#		
#		my $table_header = '<tr><td></td>' . "\n";
#
#		for my $context (@{$t_headers}) {
#			$table_header = $table_header . '<th>' . $context->label() . '</th>' . "\n"; 
#		}
#
#		$table_header = $table_header . '</tr>';
#
#		for my $element (@$elements) {
#			my $e_id = $element->id();
#			$e_id =~ s/\_/\:/;
#			if ($element->type =~ m/textBlock/) {
#				for my $context (@$t_headers) {
#					my $item = &get_item($self, $e_id, $context->id()); 
#					$table = $table  . $item->value();	
#				}
#				next;	
#			}
#			
#			my @item_array = ();
#			my %dim_hash = ();	
#
#				my $items = &get_item_all_contexts($self, $e_id);
#				for my $header_context (@{$t_headers}) {
#					my $value;	
#					for my $item (@{$items}) {
#						my $item_context = &get_context($self, $item->context());
#						my $dims = $item_context->dimension(); 	
#						if (($header_context->label() eq $item_context->label()) && 
#							(! $dims->[0] )) {
#							$value = $item->value();	
#						}
#					}
#					if ($value) {
#						push(@item_array, $value); 
#					}
#					else {
#						push(@item_array, '&nbsp;');
#					}	
#				}
#			$rows{$element->name()} = \@item_array;
#		
#		}
#
#
#
#		$table = $table . $table_header;		
#
#		for my $element (@{$elements}) {
#			my $e_id = $element->id();
#			$e_id =~ s/\_/\:/;
#			$table = $table . '<tr><td>' . $e_id . '</td>' . "\n";	
#			my $items = $rows{$element->name()};
#			for my $item (@{$items}) {
#				$table = $table . '<td>' . $item . '</td>' . "\n"; 
#			}
#		}
#
#	
#	$table = $table . "</table>";
#	$html = $html . $table;

	}
	
	$html = $html . "</body></html>";
	open(my $fh, ">$html_file") or croak "can't open $html_file because: $! \n";
	print $fh $html;
	close($fh);

}


sub get_table_headers() {
	my ($self, $table_elements) = @_;
	my @out_array = ();
	my %labels = ();	
	my @all_contexts = ();	
	for my $element (@{$table_elements}) {
					#print $element->id() . "\n";
		if (!$element) {
			print Dumper($element);	
						croak "There isn't an element \n"; 
		}	
		my $e_id = $element->id();
		$e_id =~ s/\_/\:/;	
		if ($element->subGroup eq 'xbrldt:dimensionItem') {
						#$self->{'contexts'}->{ $cont->id() } = $cont;	
			my $contexts =  &get_all_contexts($self); 
			for my $context_id (keys %{$contexts}) {
				my $context = &get_context($self, $context_id); 
						if ($context->is_dim_member($e_id)) {
										#$labels{$context->label()}++;	
							push(@all_contexts, $context);	
						}	
			}	
		}	
		else {	
			my $items = &get_item_all_contexts($self, $e_id);
			for my $item (@$items) {
						#print "\t" . $item->name() . "\t" . $item->context() . "\n";
				my $context = &get_context($self, $item->context());	
				#$labels{$context->label()}++;	
				push(@all_contexts, $context);	
			}
		}	
	}	
	#get the unique based on label  	
	
	my %seen = ();
	my @uniq = ();
	foreach my $context (@all_contexts) {
    unless ($seen{$context->label()}) {
        # if we get here, we have not seen it before
        $seen{$context->label()} = 1;
        push(@uniq, $context);
    }
	}
	#sort the buggers 
	my (@dur, @per) = ();
	for (@uniq) {
		if ($_->duration()) {
			push(@dur, $_);
		}
		else {
			push(@per, $_); 
		}
	}

	my @sorted_dur = sort { $a->duration() cmp $b->duration() 
																				|| 
													$b->endDate()->cmp($a->endDate()) } @dur;


	my @sorted_per = sort { $b->endDate()->cmp($a->endDate()) } @per; 

	push(@out_array, @sorted_dur);
	push(@out_array, @sorted_per); 
	return \@out_array;
}



sub is_table() {
	my ($self, $pres_link) = @_;

}

sub build_table() {
	my ($self, $pres_link) = @_;

}


1;

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

XBRL - Perl extension for Reading Extensible Business Reporting Language 

=head1 CAVEAT UTILITOR



=head1 SYNOPSIS

use XBRL;

my $doc = XBRL->new();
	
$doc->parse_file( "aol.xml" ); 


=head1 DESCRIPTION

Stub documentation for XBRL, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Mark Gannon <mark@truenorth.nu>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Mark Gannon 

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
