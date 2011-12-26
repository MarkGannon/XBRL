package XBRL::Schema;

use strict;
use warnings;
use Carp;
#use XML::LibXML; 
#use XML::LibXML::XPathContext; 

our $VERSION = '0.01';

use base qw(Class::Accessor);

XBRL::Schema->mk_accessors( qw( namespace file xpath  ) );

sub new() {
	my ($class, $args) = @_;
	my $self = { namespace => $args->{'namespace'},
							file => $args->{'file'}, 
							xpath => $args->{'xpath'} };
	bless $self, $class;


	return $self;
}





1;

