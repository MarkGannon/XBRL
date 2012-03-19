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


our $VERSION = '0.01';
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
	my ($self) = @_;
	my $label_arcs = $self->{'lab'}->findnodes("//*[local-name() =  'labelArc']");
	my $label_locs =  $self->{'lab'}->findnodes("//*[local-name() =  'loc']"); 
	my $label_labels =   $self->{'lab'}->findnodes("//*[local-name() =  'label']"); 

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

	my $d_link = $self->{'def'}->findnodes("//*[local-name() = 'definitionLink'][\@xlink:role = '" . $sec_uri . "' ]"); 

	if ($d_link) {
		my @definition_arcs = $d_link->[0]->getChildrenByLocalName('definitionArc'); 			
		for my $d_arc (@definition_arcs) {
			my $arcrole = $d_arc->getAttribute('xlink:arcrole');
			if ($arcrole eq 'http://xbrl.org/int/dim/arcrole/hypercube-dimension') {
				return $d_link;
			}
		}		
	}
	return undef;
}


sub get_label() {
	my ($self, $search_id, $role) = @_;

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

1;

