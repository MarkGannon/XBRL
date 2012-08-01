package XBRL::TableXML;

use strict;
use warnings;
use XML::LibXML;
use Data::Dumper;
use Carp;

our $VERSION = '0.03';

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

	if (&has_entries(\@items)) {
		my $row = XML::LibXML::Element->new("row");
		$row->setAttribute("xbrl-item", $items[0]);
	
	
		for (my $i = 1; $i < @items; $i++) {
			my $cell = XML::LibXML::Element->new("cell");
			my $content = $items[$i];
			$cell->appendText($content);
			$row->appendChild($cell);	
		}
		
		$self->{'table'}->appendChild($row);
	}
}

sub has_entries() {
	#take the array representing a row and check to see if it has any numbers
	#return 1 if it does and undef if it does not
	#there should be no reason to call this function externally	
	
	my ($row_array) = @_;  

	my $number;

	FOO: {
		for (my $i = 1; $i < @{$row_array}; $i++) {
	
			if (($row_array->[$i] =~ m/\d/) || (($row_array->[$i] =~ m/\w/) && ($row_array->[$i] !~ m/nbsp/ )) ){
				$number = 1;
				last FOO;
			}
		}
	}
	return $number;
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

sub getHeader() {
	my ($self) = @_; 
	my $headers =$self->{'table'}->findnodes("//header"); 
	
	my $cells = $headers->[0]->getChildrenByLocalName('cell'); 	
	my @out_array;

	for my $cell (@{$cells}) {
		my $value = $cell->textContent();
		push(@out_array, $value);
	}
	
	return(\@out_array);
}

sub getRows() {
	my ($self) = @_;
	my @out_array;	
	
	my $rows = $self->{'table'}->findnodes("//row");
	
	for my $row (@{$rows}) {	
		my $row_string = $row->getAttribute('xbrl-label');	
		my $id = $row->getAttribute('xbrl-item');	
		my $cells = $row->getChildrenByLocalName('cell'); 	

		for my $cell(@{$cells}) {
			$row_string = $row_string . "\t" . $cell->textContent();
		}
			
		push(@out_array, $row_string);	
	}	
	return \@out_array;
}



sub label() {
	my ($self, $row_number, $label) = @_;
	my $rows = $self->{'table'}->findnodes("//row");
	$row_number = $row_number -1;
	
	my $item_label = $rows->[$row_number]->getAttribute('xbrl-label');

	if ($label) {
		$rows->[$row_number]->setAttribute('xbrl-label', $label );	
	}
	else {
			return $item_label;			
	}
	return undef;
}

sub get_row_id() {
	my ($self, $row_number) = @_;
	
	my $rows = $self->{'table'}->findnodes("//row");
	
	$row_number = $row_number -1;
	
	my $item_id = $rows->[$row_number]->getAttribute('xbrl-item');

	return($item_id);

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

	$row_number = $row_number - 1;
	$col_number = $col_number -1;
	my $rows = $self->{'table'}->findnodes("//row");

	my @cells = $rows->[$row_number]->getChildrenByLocalName('cell'); 
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

sub get_ids() {
	my ($self) = @_;

	my @out_array;

	my $rows = $self->{'table'}->findnodes("//row");

	for my $row (@{$rows}) {
		push(@out_array, $row->getAttribute('xbrl-item'));
	}
	
	return(\@out_array);
}




=head1 XBRL::TableXML 

XBRL::TableXML - OO Module for Encapsulating XBRL Tables in XML 

=head1 SYNOPSIS

  use XBRL::TableXML;
	
	my $xml_table = XBRL::TableXML->new($xbrl_doc, $uri); 

	$xml_table->addHeader(@col_labels); 	

	my $colum_headers = $xml_table->getHeader(); 
	
	$xml_table->addRow($label, @row_values);	

	$xml_table->setCell($row_number, $col_number, $text_value);

	my $cell_contents = $xml_table->getCell($row_number, $col_number);

	my $rows = $xml_table->getRows();

	my $number_rows = $xml_table->getTableRows();
	
	$xml_table->label($row_number, $label); 

	my $row_label = $xml_table->label($row_number);

	my $xml_text = $xml_table->as_text();

	my $xbrl_tags = $xml_table->get_ids();

=head1 DESCRIPTION

This module is part of the XBRL modules group and is intended for use with XBRL.

=over 4

=item new 
  	
		use XBRL::TableXML;
		my $xml_table = XBRL::TableXML->new($xbrl_doc, $uri); 

Object contstructor.  Takes an XBRL object as well as a 
URI specifying which section to create a table from.

=item addHeader

		$xml_table->addHeader(@col_labels); 	

Adds text entries to the column headers.  Should include a blank or 
'&nbsp;' as the first entry.

=item getHeader

	my $colum_headers = $xml_table->getHeader(); 

Returns an array reference with the text values for the column headers 

=item addRow

		$xml_table->addRow($label, @row_values);	

Adds a row to the end of the table.  The label can either be specified seperately,
or included as the first entry in the array of values.

=item setCell

	$xml_table->setCell($row_number, $col_number, $text_value);

Sets content for the specified cell.

=item getCell

	my $cell_contents = $xml_table->getCell($row_number, $col_number);

Returns the text value of the specified cell.

=item getRows

	my $rows = $xml_table->getRows();

Returns an array ref where each item is a tab seperated list of the 
rows contents.

=item getTableRows 

	my $number_rows = $xml_table->getTableRows();

Returns the number of rows (exclusive of the header row) in the table.

=item label

	$xml_table->label($row_number, $label); 
	my $row_label = $xml_table->label($row_number);

If the label value is included sets the label for the row.  If no label value is included,
returns the label value for the row.


=item as_text

	my $xml_text = $xml_table->as_text();

Returns the XML table as text.

=item get_ids

	my $xbrl_tags = $xml_table->get_ids();

Returns an array reference with a list of all the XBRL tags (one per row).  


=back

=head1 AUTHOR

Mark Gannon <mark@truenorth.nu>

=head1 SEE ALSO

Modules: XBRL 

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



