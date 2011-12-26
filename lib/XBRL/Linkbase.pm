package XBRL::Linkbase;

use strict;
use warnings;
use Carp;
#use XML::LibXML; 
#use XML::LibXML::XPathContext; 
#use Data::Dumper;

our $VERSION = '0.01';

use base qw(Class::Accessor);

XBRL::Unit->mk_accessors( qw( id ) );

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


}

1;

