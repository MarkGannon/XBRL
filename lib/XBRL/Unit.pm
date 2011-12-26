package XBRL::Unit;

use strict;
use warnings;
use Carp;
#use XML::LibXML; 
#use XML::LibXML::XPathContext; 
#use Data::Dumper;

our $VERSION = '0.01';

use base qw(Class::Accessor);

XBRL::Unit->mk_accessors( qw( id measure numerator denominator ) );

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
	my ($self, $xml) = @_;

	my $id = $xml->getAttribute('id');
	if (! $id ) { croak "no id from get attribute\n"; }	
	
	$self->{'id'} = $id; 


	my @child_nodes = $xml->getElementsByTagName('xbrli:measure');

	#if ($child_nodes[0]) {
	if (@child_nodes == 1) {
		$self->{'measure'} = $child_nodes[0]->textContent();
	}
	elsif (@child_nodes == 2) {
		my @nominators = $xml->getElementsByTagName('xbrli:unitNumerator'); 
		my @measures = $nominators[0]->getElementsByTagName('xbrli:measure');	
		$self->{'numerator'} = $measures[0]->textContent();	
		my @denominators = $xml->getElementsByTagName('xbrli:unitDenominator'); 	
		my @d_measures = $denominators[0]->getElementsByTagName('xbrli:measure');	
		$self->{'denominator'} = $d_measures[0]->textContent();	
	}

}

1;

