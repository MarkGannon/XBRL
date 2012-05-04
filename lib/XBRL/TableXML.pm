package XBRL::TableXML;

use strict;
use warnings;
use XML::LibXML;
use Data::Dumper;

our $VERSION = '0.01';

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);



sub new() {
	my ($class, $xbrl_doc, $uri ) = @_;
	my $table = XML::LibXML::Element->new("table");	
	my $self = { table => $table }; 
	
	bless $self, $class;


	return $self;
}

sub addRow() {
	my ($self, @items) = @_;

	my $row = XML::LibXML::Element->new("row");
	$row->setAttribute("xbrl-item", $items[0]);

	for (my $i = 1; $i < @items; $i++) {
		my $cell = XML::LibXML::Element->new("cell");
		$cell->appendText($items[$i]);	
		$cell->setAttribute("order", $i);	
		$row->appendChild($cell);	
	}
	
	$self->{'table'}->appendChild($row);

}

sub addHeader() {
	my ($self, @items) = @_;

	my $head = XML::LibXML::Element->new("header");

	for (my $i = 0; $i < @items; $i++) {
		my $cell = XML::LibXML::Element->new("cell");
		$cell->appendText($items[$i]);	
		$head->appendChild($cell);	
	}
	
	$self->{'table'}->appendChild($head);

}





sub label() {
	my ($self, $row_number, $label) = @_;
	my $rows = $self->{'table'}->findnodes("//row");
	$row_number = $row_number -1;
	print STDERR "Label for $row_number\n";

	my $item_name = $rows->[$row_number]->getAttribute('xbrl-item');

	if ($label) {
		print STDERR "trying to set $label \n";	
		print STDERR "Value before: " . $rows->[$row_number]->getAttribute('xbrl-item') . "\n";	
		$rows->[$row_number]->setAttribute('xbrl-item', $label );	
		print STDERR "Value After: " . $rows->[$row_number]->getAttribute('xbrl-item') . "\n";	
	}
	else {
			print STDERR "Returning " . $item_name . "\n";	
			return $item_name;			
	}
	return undef;
}

sub getCell() {
	my ($self, $row_number, $col_number) = @_;
	$row_number = $row_number - 1;
	$col_number = $col_number -1;
	my $row = $self->{'table'}->findnodes("//row");
	#print $row->[$row_number]->toString() . "\n";	
	#my @loc_links = $section->[0]->getChildrenByLocalName('loc'); 
	my @cells = $row->[$row_number]->getChildrenByLocalName('cell'); 
 
	if (!$cells[$col_number]) {
		return undef;	
	}
	else {
		return($cells[$col_number]->textContent);
	}
}

sub setCell() {
	my ($self, $row_number, $col_number, $content) = @_;

	print STDERR "Set Cell\n";
	print STDERR "$row_number, $col_number, $content \n";
	$row_number = $row_number - 1;
	$col_number = $col_number -1;
	my $row = $self->{'table'}->findnodes("//row");
	
	my @cells = $row->[$row_number]->getChildrenByLocalName('cell'); 
	if ($cells[$col_number]) {
		$cells[$col_number]->nodeValue($content);
	}
}

sub getTableRows() {
	my ($self) = @_;

	my $nodelist = $self->{'table'}->findnodes("//row");
	
	return(scalar @{$nodelist});
}


sub as_text() {
	my ($self) = @_;
	return($self->{'table'}->toString());
}

sub clear_empty_cols() {


}






=head1 XBRL::Item 

XBRL::Item - OO Module for Encapsulating XBRL Items 

=head1 SYNOPSIS

  use XBRL::Item;

	my $item = XBRL::Item->new($item_xml);	
	
=head1 DESCRIPTION

This module is part of the XBRL modules group and is intended for use with XBRL.

new() Object contstructor.  Optionally takes the item XML from the instance document. 

decimal() Get or set the number of decimals to adjust the value by. 

unit() Get or set the unitRef for the item. 

id() Get or set the item's ID.

context() Get or set the item's contextRef value. 

name() Get or set the item's name.  

value() Get or set the item's value. 

localname() Get or set the localname for the item  

prefix() Get or set the prefeix for the item  

namespace() Get or set the prefix for the item  

adjValue() Get or set the item's adjusted value (actuall value with the 
						decimals adjusted based on the decimals attribute. 


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


