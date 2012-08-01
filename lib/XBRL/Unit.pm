package XBRL::Unit;

use strict;
use warnings;
use Carp;

our $VERSION = '0.03';

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

=head1 NAME

XBRL::Unit - Perl Objected-Oriented Module for ecapsulating XBRL Units 

=head1 SYNOPSIS

  use XBRL::Unit;  
		
	my $unit = XBRL::Unit->new($unit_xml); 	

	my $unit_id = $unit->id():

	my $unit_measure = $unit->measure();

	my $unit_numerator = $unit->numerator(); 

	my $unit_denominator = $unit->denominator();


=head1 DESCRIPTION

This module is intended to work in conjunction with the XBRL module for parsing Extensible Business Reporting Language docuements.  

=over 4

=item new

Constructor for the object requires a scalar containing the XML text 
of the unit. 
		
=item id

Returns a scalar variable with the unit's ID as assigned in the 
instance document.

=item measure

Returns a scalar variable with a string describing the 
measure for the unit (e.g. iso4217:USD). 

=item numerator

Returns a scalar variable with a string describing the 
the numerator measure (e.g. iso4217:USD) in the event the 
unit is representing a division of two types of 
units (e.g Dollars per Share).

=item denominator

Returns a scalar variable with a string describing the 
the denominator measure (e.g. xbrli:shares) in the event the 
unit is representing a division of two types of 
units (e.g Dollars per Share).


=back


=head1 SEE ALSO

Modules: XBRL XBRL::Element XBRL::Table 

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



