package XBRL::Label;

use strict;
use warnings;
use Carp;
#use XML::LibXML; 
#use XML::LibXML::XPathContext; 

our $VERSION = '0.01';

use base qw(Class::Accessor);

XBRL::Label->mk_accessors( qw( name id role lang value ) );

sub new() {
	my ($class, $in_xml) = @_;
	my $self = { }; 
							
	bless $self, $class;


	if ($in_xml) {
		&parse($self, $in_xml);
	}

	return $self;
}


sub parse() {
	my ($self, $xml_instance) = @_;
	#this parses where labels are seperated into labelLink sections
	#but not all label linkbases use that 
	
	my $loc_node = $xml_instance->getChildrenByLocalName('loc');
	my $href = $loc_node->[0]->getAttribute('xlink:href');	
	$href =~ m/\#([A-Za-z0-9_-].+)$/; 	
	
	$self->{'name'} = $1; 	

	my $label_node = $xml_instance->getChildrenByLocalName('label');

	my $role = $label_node->[0]->getAttribute('xlink:role');
	
	#$role =~ m/.+\/([a-zA-Z].+)$/;
	#$self->{'role'} = $1;
	$self->{'role'} = $role;

	$self->{'lang'} = $label_node->[0]->getAttribute('xml:lang');
	$self->{'id'} = $label_node->[0]->getAttribute('id');
	$self->{'value'} = $label_node->[0]->textContent();
}



1;

