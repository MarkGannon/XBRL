package XBRL::TableHTML;

use strict;
use warnings;
use XML::LibXML;
use Data::Dumper;
use HTML::Table;

our $VERSION = '0.02';

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);



sub new() {
	my ($class, $arg_ref  ) = @_;
	my $self = { xml => $arg_ref->{'xml'} }; 
								
	
	bless $self, $class;

	if ($self->{'xml'}) { 
		&parse_xml($self); 
	}

	return $self;
}


sub parse_xml() {
#take the xml and parse into a html::table thingie
	my ($self) = @_;

	my $xml = $self->{'xml'};

	my $table = HTML::Table->new( #-border => 1,
																-evenrowclass=> 'even',
																-oddrowclass=> 'odd' );
	
	my $header_content = $xml->getHeader(); 

	#$table->addRow(@{$header_content});

	$table->addSectionRow('thead', 0, @{$header_content});

	y $rows = $xml->getRows();

	for my $row (@{$rows}) {
		my @items = split("\t", $row);
		$table->addRow(@items);	
	}

	my $num_cols = $table->getTableCols();
	
	$table->setColClass(1, "label");

	#for (my $i = 2; $i <=$num_cols; $i++) {
	#	$table->setColClass($i, "number");
	#}

	#set class for either a number or text for cells
	
	my $total_rows = $table->getTableRows();

		for (my $j = 2; $j <= $num_cols; $j++) {
			my $col_text = 0;
			for (my $i = 1; $i <= $total_rows; $i++) {
				my $cell = $table->getCell($i, $j);
			
				if (!$cell) { 
					$cell = '&nbsp;';	
				} 

				if ($cell =~ m/\&nbsp/) {
					#do nothing
				}
				elsif ($cell =~ m/[A-Za-z]+/g) {
					$col_text++;
				}
			}
			if ($col_text > 0) {
				for (my $i = 1; $i <= $total_rows; $i++) {
					$table->setCellClass($i, $j, "text");
				}
			}
			else {
				for (my $i = 1; $i <= $total_rows; $i++) {
					$table->setCellClass($i, $j, "number");
					my $cell = $table->getCell($i, $j); 	
					if ($cell) {	
						my $commad = &commify($table->getCell($i, $j));	
						$table->setCell($i, $j, $commad);	
					}	
				}
			}
		}


	$self->{'html_table'} = $table;
}

sub commify() {
		my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}


sub asText() {
#return the html::table thingie as text 
	my ($self) = @_;

	return $self->{'html_table'}->getTable();	
}




=head1 XBRL::TableHTML 

XBRL::HTML - OO Module for Creating HTML Tables from XBRL::TableXML objects 

=head1 SYNOPSIS

  use XBRL::TableHTML;

	my $html_table = XBRL::TableHTML->new( {xml => $table_xml_object} );	
	
=head1 DESCRIPTION

This module is part of the XBRL modules group and is intended for use with XBRL.

=over 4

=item new 
	
	my $html_table = XBRL::TableHTML->new( { xml => $xml_table } );	

Object contstructor.  Optionally takes an XBRL::TableXML object and turns into an
HTML::Table object

=item asText

	my $html_text = $html_table->asText();

Returns the text of the HTML::Table object. 

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


