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





1;

