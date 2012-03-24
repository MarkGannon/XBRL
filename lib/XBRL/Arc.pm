package XBRL::Arc;

use strict;
use warnings;
use Carp;

our $VERSION = '0.01';

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

new() Object constructor  

from_full() Get or set the from_full attribute.  

from_short() Get or set the from_short attribute. 

to_full() Get or set the to_full attribute.

to_short() Get or set the to_short attribute. 

order() Get or set the order attribute. 

arcrole() Get or set the arcrole attribute. 

usable() Get or set the usable attribute (true or false). 

closed() Get or set the closed attribute (true or false). 

contextElement() Get or set the contextElement  

prefLabel() Get or set the identifier of the preferredLabel  


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




