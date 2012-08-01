package XBRL::Taxonomy;

use strict;
use warnings;
use Carp;
use XML::LibXML; 
use XML::LibXML::XPathContext; 
use XML::LibXML::NodeList; 
use XBRL::Element;
use XBRL::Label;
use Data::Dumper;


our $VERSION = '0.03';
our $agent_string = "Perl XBRL Library $VERSION";

use base qw(Class::Accessor);

XBRL::Taxonomy->mk_accessors( qw( elements pre def lab cal schemas main_schema ) );


sub new() {
	my ($class, $args) = @_;
	#my $self = { main_schema => $args->{'main_schema'}  };
	my $self = { };
	bless $self, $class;

	if ($args->{'main_schema'}) {
		&add_schema($self, $args->{'main_schema'});
	}
	
	$self->{'main_schema'} = $args->{'main_schema'}->namespace();
	return $self;
}

sub set_main_schema() {
	my ($self, $ms) = @_;
	$self->{'main_schema'} = $ms;
}

sub get_lb_files() {
	my ($self) = @_;
	my @out_array;	
	my $ms = $self->{'main_schema'};
	my $main_xpath = $self->{'schemas'}->{$ms}->xpath();	
	my $lbs = $main_xpath->findnodes("//*[local-name() = 'linkbaseRef']"  );

	for my $lb (@$lbs) {
		my $lb_file = $lb->getAttribute('xlink:href');	
		push(@out_array, $lb_file); 
	}
	return \@out_array;
}

sub get_other_schemas() {
	my ($self) = @_;
	my @out_array;	
	my $ms = $self->{'main_schema'};
 	my $main_xpath = $self->{'schemas'}->{$ms}->xpath();	
	my $other_schemas = $main_xpath->findnodes("//*[local-name() = 'import']"); 	
	for my $other (@$other_schemas) {
		my $location_url  = $other->getAttribute('schemaLocation');
		push(@out_array, $location_url);	
	}
	return \@out_array;
}

sub add_schema() {
	my ($self, $schema) = @_;
		my $ns = $schema->namespace();	
		$self->{'schemas'}->{$ns} = $schema;	
		#print "Schema Namespace: " . $ns . "\n";	
		my $element_nodes = $schema->xpath()->findnodes("//*[local-name() = 'element']");
		for my $el_xml (@$element_nodes) {
						#print "\tElement Node: " . $el_xml->toString());	
			my $e = XBRL::Element->new($el_xml);
			if ($e->id()) { 
							#print "\tID: " . $e->id() . "\n";	
				$self->{'elements'}->{$e->id()} = $e;	
			}	
		}
}


sub set_labels() {
	#Load the array of labels 
	my ($self, $xpath) = @_;
	my $label_arcs 		= $xpath->findnodes("//*[local-name() =  'labelArc']");
	my $label_locs 		=	$xpath->findnodes("//*[local-name() =  'loc']"); 
	my $label_labels 	=	$xpath->findnodes("//*[local-name() =  'label']"); 

	my @label_array;

	for my $arc (@{$label_arcs}) {
		for my $loc (@{$label_locs}) {
			if ($arc->getAttribute('xlink:from') eq $loc->getAttribute('xlink:label')) {
				for my $label_node (@{$label_labels}) {
					if ( $arc->getAttribute('xlink:to') eq $label_node->getAttribute('xlink:label') ) {
								
							my $label = XBRL::Label->new();	
							my $href = $loc->getAttribute('xlink:href');	
							$href =~ m/\#([A-Za-z0-9_-].+)$/; 	
							$label->name($1);	
							$label->role($label_node->getAttribute('xlink:role'));
							$label->lang($label_node->getAttribute('xml:lang'));	
							$label->id($label_node->getAttribute('id'));
							$label->value( $label_node->textContent() );
							push(@label_array, $label);	
					}

				}
			}
		}

	}
	$self->{'labels'} =\@label_array; 
}


sub get_elementbyid() {
	my ($self, $e_id) = @_;
	
	return( $self->{'elements'}->{$e_id} );
}


sub get_arcs() {
	my ($self, $type, $uri) = @_;
	my $arcs = $self->{$type}->{$uri};

	return $arcs;
}


sub get_sections() {
	my ($self) = @_;
	my @out_array = ();	
	my $ms = $self->{'main_schema'}; 
	my $search_schema = $self->{'schemas'}->{$ms};
	my $search_xpath = $search_schema->xpath();
	my $sections = $search_xpath->findnodes('//link:roleType');
	
	for my $section (@$sections) {
		my $uri = $section->getAttribute('roleURI');	
		my $def = $section->findnodes('link:definition');
		$def =~ m/(^\d+\d)/;	
		my $order = $1;	
		push(@out_array, { def => $def, uri => $uri, order => $order }); 
	}
	
	my @sorted_array = sort { $a->{'order'} <=> $b->{'order'} } @out_array;	
	
	return \@sorted_array;
}


sub in_def() {
	#take a section uri and check if there is a 
	#section for it in the definition link base
	#return nodelist of def  if true,  undef if not
	my ($self, $sec_uri) = @_; 

	my $arcs = $self->{'def'}->{$sec_uri};

	if ($arcs->[0]) {
		return $arcs;
	}

	return undef;
}


sub get_label() {
	my ($self, $search_id, $role) = @_;
	#FIXME May need to move away from 2003 here.
	
	if (!$role) {
		$role = 'http://www.xbrl.org/2003/role/label';
	}

	for my $label (@{$self->{'labels'}}) {
		if (($label->name() eq $search_id) && ($label->role() eq $role)) {
			return $label->value();
		}
	}
	
	$role = 'http://www.xbrl.org/2003/role/label';
	
	for my $label (@{$self->{'labels'}}) {
		if (($label->name() eq $search_id) && ($label->role() eq $role)) {
			return $label->value();
		}
	}
}

=head1 XBRL::Taxonomy 

XBRL::Taxonomy - OO Module for Parsing XBRL Taxonomies 

=head1 SYNOPSIS

  use XBRL::Taxonomy;

  my $taxonomy = XBRL::Taxonomy->new( {main_schema => $schema} );

	$taxonomy->add_schema($next_schema);

	my $link_base_file_names = $taxonomy->get_lb_files();	

	
=head1 DESCRIPTION

This module is part of the XBRL modules group and is intended for use with XBRL.

=over 4

=item new 

	my $taxonomy = XBRL::Taxonomy->new( { main_schema => <schema object here> })  

Object contstructor that requires an XBRL::Schema object of the 
XBRL instance document.  Usually bundled with the instance document 
with a file extension of .xsd.  


item get_lb_files 

	my $link_base_file_names = $taxonomy->get_lb_files();	

Returns an array reference with the filenames for all 
the linkbases contained in the main schema.  

=item get_other_schemas 

Returns an array reference with the location URLs of all schemas  
included in the main schema.

=item add_schema 

Takes an XBRL::Schema object and adds it to the taxonomy  

=item set_labels

Looks labels up in the Taxonomy's Label Linkbase and populates an 
array of XBRL::Label objects for resolving an element's name. 

=item get_elementbyid 

Looks up an element in the Taxonomy using the 
element's ID as assigned in the schema.

=item get_sections 

Returns an array reference of anonymous hashes where the 
key values are: 
def -- the value of <link:definition> in the instance schema.  Frequently 
used as the title of the section.
uri -- the value of the <link:roleType> roleURI attribute.  Used to look
up the section entries in the Presentation, Definition, and Calculation
Linkbases.
order -- The value of the number at the beginning of the <link:definition>
element. 

=item in_def 

Takes the role URI and determines returns true if the URI appears in 
in the Definition Linkbase and should be used for rendering a table in preference
over the entry in the Presentation Linkbase.						

=item get_label 

Takes an element id and an optional role in the form
of the role's URI (e.g. http://www.xbrl.org/2003/role/totalLabel).  If no 
role is specified the function will return the one with a URI of: 
http://www.xbrl.org/2003/role/label.  

=item elements() 

Returns an array reference of all the element objects associated with 
the main schema and any schemas that have been added 

=item pre 

Returns or sets an XML::LibXML::XPathContext object of the Presentation Linkbase    

=item def 

Returns or sets an XML::LibXML::XPathContext object of the Definition Linkbase    

=item cal 

Returns or sets an XML::LibXML::XPathContext object of the Calculation Linkbase    

=item lab 

Returns or sets an XML::LibXML::XPathContext object of the Label Linkbase    

=item schemas 

Returns or sets an hash ref where the values are XBRL::Schema objects and 
the keys are the namespaces of the schemas 

=item main_schema 

Returns or sets the namespace for the main_schema  

=back

=head1 AUTHOR

Mark Gannon <mark@truenorth.nu>

=head1 SEE ALSO

Modules: XBRL XBRL::Schema XBRL::Element XBRL::Label 

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


1;

