package XBRL::Schema;

use warnings;
use Carp;

our $VERSION = '0.02';

use base qw(Class::Accessor);

XBRL::Schema->mk_accessors( qw( namespace file xpath  ) );

sub new() {
	my ($class, $args) = @_;
	my $self = { namespace => $args->{'namespace'},
							file => $args->{'file'}, 
							xpath => $args->{'xpath'} };
	bless $self, $class;

	if (!$self->{'namespace'}) {
		my $xpath = $self->{'xpath'};		
		my $ns_nodes = $xpath->findnodes('//*[@targetNamespace]');
		my $ts = $ns_nodes->[0]->getAttribute('targetNamespace');
		$self->{'namespace'} = $ts;
	}

	return $self;
}


=head1 NAME

XBRL::Schema - Perl OO Module for encapsulating XBRL Schema Information 

=head1 SYNOPSIS

  use XBRL::Schema; 
	
	my $schema = XBRL::Schema->new( { file=> $schema_file, xpath=>$schema_xpath });

=head1 DESCRIPTION

This module is part of the XBRL modules group and is intended for use with XBRL.

=over 4

=item new

	my $schema = XBLR::Schema->new( { file=><schema file path>, 
						xpath=><XML::LibXML::XPathContext of Schema> } )

The module contstructor requires both the file path and an 
XML::LibXML::XPathContext of the schema.

=item namespace

Get or set the target namespace of the schema 
(e.g http://www.xbrl.org/2003/instance ) 

=item file

Get or set the filepath for the schema 

=item xpath

Get or set the XML::LibXML::XPathContext of the schema 

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


