package XBRL::Arc;

use strict;
use warnings;
use Carp;

our $VERSION = '0.03';

use base qw(Class::Accessor);

XBRL::Arc->mk_accessors( qw( from_full from_short to_full to_short order arcrole usable closed contextElement prefLabel ) );

sub new() {
	my ($class) = @_;
	my $self = { }; 
							
	bless $self, $class;



	return $self;
}

=head1 XBRL::Arc

XBRL::Arc - OO Module for Ecapsulating XBRL Arcs  

=head1 SYNOPSIS

  use XBRL::Arcs;

	my $arc = XBRL::Arc->new();
	
	$arc->order(4);	

	
=head1 DESCRIPTION

This module is part of the XBRL modules group and is intended for use with XBRL.


=over 4

=item new
	
	my $arc = XBRL::Arc->new();

Object constructor  

=item from_full 

Get or set the from_full attribute.  

=item from_short 

Get or set the from_short attribute. 

=item to_full

Get or set the to_full attribute.

=item to_short 

Get or set the to_short attribute. 

=item order 

Get or set the order attribute. 

=item arcrole

Get or set the arcrole attribute. 

=item usable

Get or set the usable attribute (true or false). 

=item closed 

Get or set the closed attribute (true or false). 

=item contextElement

Get or set the contextElement  

=item prefLabel

Get or set the identifier of the preferredLabel  

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




