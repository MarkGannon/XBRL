package XBRL::Item;

use strict;
use warnings;

our $VERSION = '0.01';

use base qw(Class::Accessor);

XBRL::Item->mk_accessors( qw( decimal unit id context name value localname prefix namespace label type subGroup abstract nillable period balance adjValue ) );




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
	if ($self->{'decimal'}) {	
		$self->{'adjValue'} = &adjust($self);
	}
	else {
		$self->{'adjValue'} = $self->{'value'};
	}
}




sub adjust() {
	my ($self) = @_;
	my $number = $self->{'value'};
	my $changer = $self->{'decimal'}; 
	$changer = $changer * -1;
	my $divsor = "10";
	for (my $i = 0; $i < $changer; $i++) {
		$divsor = $divsor . '0';
	}
	my $adj_number = $number / $divsor;
	return($adj_number); 
}


1;


