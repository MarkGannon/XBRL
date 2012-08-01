package XBRL::Label;

use strict;
use warnings;
use Carp;
#use XML::LibXML; 
#use XML::LibXML::XPathContext; 

our $VERSION = '0.03';

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



=head1 NAME

XBRL::Label - Perl OO Module for encapsulating XBRL Label information 

=head1 SYNOPSIS

  use XBRL::Label; 

	my $label = XBRL::Label->new();	

	$label->name("us-gaap_AccountsReceivableNet");	


=head1 DESCRIPTION

This module is part of the XBRL modules group and is intended for use with XBRL.

=over 4

=item new 

Object constructor  

=item id

Get or set the ID for the object.  The ID is everything after # of the xlink:href
attribute of the labels "loc" element.    

=item role

Get or set the label's role.  This is the xlink:role attribute of the label's
label element.   

=item lang

Get or set the label's language.  

=item value

Get or set the label's value.  

=back

=head1 AUTHOR

Mark Gannon <mark@truenorth.nu>

=head1 SEE ALSO

Modules: XBRL XBRL::Taxonomy 

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




