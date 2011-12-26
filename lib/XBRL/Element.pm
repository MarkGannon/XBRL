package XBRL::Element;

use strict;
use warnings;
use Carp;
#use XML::LibXML; 
#use XML::LibXML::XPathContext; 

our $VERSION = '0.01';

use base qw(Class::Accessor);

XBRL::Element->mk_accessors( qw( name id type subGroup abstract nillable periodType ) );

sub new() {
	my ($class, $xml) = @_;
	my $self = { };  
	
	bless $self, $class;

	if ($xml) {
		$self->{'name'} = $xml->getAttribute('name');
		$self->{'id'} = $xml->getAttribute('id');
		$self->{'type'} = $xml->getAttribute('type');
		$self->{'subGroup'} = $xml->getAttribute('substitutionGroup');
		$self->{'abstract'} = $xml->getAttribute('abstract');
		$self->{'nillable'} = $xml->getAttribute('nillable');
		$self->{'periodType'} = $xml->getAttribute('xbrli:periodType');
	}


	return $self;
}




1;

