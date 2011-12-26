package XBRL::Item;

use strict;
use warnings;

our $VERSION = '0.01';

use base qw(Class::Accessor);

XBRL::Item->mk_accessors( qw( decimal unit id context name value localname prefix namespace label type subGroup abstract nillable period balance ) );




sub new() {
	my ($class, $instance_xml, $schema_xml) = @_;
	my $self = { decimal => undef,
								unit => undef,
								id => undef,
								context => undef,
								name => undef,
								value => undef,
								label => undef };
	bless $self, $class;

	if ($instance_xml) {
		&parse($self, $instance_xml, $schema_xml);
	}

	return $self;
}

sub parse() {
	my ($self, $instance_xml, $schema_xml) = @_;

	$self->{'decimal'} 	= $instance_xml->getAttribute('decimals');
	$self->{'unit'} 		= $instance_xml->getAttribute('unitRef');
	$self->{'id'} 			= $instance_xml->getAttribute('id');
	$self->{'context'} 	= $instance_xml->getAttribute('contextRef');
	$self->{'name'} 		= $instance_xml->nodeName();
	$self->{'localname'} = $instance_xml->localname();
	$self->{'prefix'} = $instance_xml->prefix();
	$self->{'namespace'} = $instance_xml->namespaceURI();
	$self->{'value'} 		= $instance_xml->textContent();
	$self->{'label'} = $instance_xml->localname();
}

1;


