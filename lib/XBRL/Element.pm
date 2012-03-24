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

=head1 XBRL::Element

XBRL::Element - OO Module for Encapsulating XBRL Elements  

=head1 SYNOPSIS

  use XBRL::Element;

	my $element = XBRL::Element->new( $element_xml );

	my $element_id = $element->id();


=head1 DESCRIPTION

This module is part of the XBRL modules group and is intended for use with XBRL.

new() Constructor for object takes the element XML from the schema and parses it.

name() Get or set the Element's name.

id() Get or set the element's ID. 

type() Get or set the element's type. 

subGroup Get or set the element's subGroup  

abstract Get or set the element's abstractedness (true or false) 

nillable Get or set whether the element is nillable (true or false) 

periodType Get or set the element's period type.  


=head1 AUTHOR

Mark Gannon <mark@truenorth.nu>

=head1 SEE ALSO

Modules: XBRL XBRL::Schema 

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




