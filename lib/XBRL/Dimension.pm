package XBRL::Dimension;

use strict;
use warnings;
use Carp;
use XML::LibXML; #::Element; 
use XML::LibXML::NodeList;
use XBRL::Arc;
use HTML::Table;
use XBRL::TableXML;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

our $VERSION = '0.02';

sub new() {
	my ($class, $xbrl_doc, $uri) = @_;
	my $self = { xbrl => $xbrl_doc,
								uri => $uri };
	bless $self, $class;
	
	return $self;
}

sub get_xml_table() {
	my ($self) = @_;
	my $table;
	if (&is_landscape($self)) {
			$table = &make_land_table($self); 
		}
		else {	
			$table = 	&make_port_table($self); 
		}	
	
	return $table;
}


sub make_port_table() {
	my ($self) = @_; 
	my $uri = $self->{'uri'};	
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
#	my $table = HTML::Table->new(-border => 1);
	my $table = XBRL::TableXML->new(); 
	
	my $header_contexts	= &get_header_contexts($self); 
	my @col_labels;
	my $hypercubes = &get_hypercubes($self);
	
	for my $context (@{$header_contexts}) {
		push(@col_labels, $context->label());	
	}
	#TODO find millions or thousands field and use it in
	#the first column
	$table->addHeader('&nbsp;', @col_labels); 	

	#my (@domain_names, @row_elements);	
	for my $hcube (@{$hypercubes}) {
		my $domain_names = &get_domain_names($self, $hcube);	
		my $row_elements = &get_row_elements($self, $hcube);	
		if ($domain_names->[0]) {	
			for my $domain (@{$domain_names}) {
				my $d_label = $tax->get_label($domain);	
				$table->addRow($d_label);	
				for my $thingie (@{$row_elements}) {
					my @row_items;	
					my $items = &get_domain_item($self, $domain, $thingie);
					next unless ($items->[0]);	
					for my $h_context (@{$header_contexts}) {
						my $value;	
						for my $item (@{$items}) {
							my $item_context = $xbrl_doc->get_context($item->context());
							if ($item_context->label() eq $h_context->label()) {	
								$value = $item->adjValue();	
								push(@row_items, $item->adjValue());
							}
						}
						if (!$value) {	
							push(@row_items, '&nbsp;');
						}	
					}	
					$table->addRow($thingie, @row_items);	
				}
			}
		}	
		else {
			for my $row (@{$row_elements}) {
				my @row_elements;
				my $items = &get_free_items($self, $row);  
				for my $h_context (@{$header_contexts}) {
					my $value;	
					for my $item (@{$items}) {
						my $item_context = $xbrl_doc->get_context($item->context());
						if ($h_context->label() eq $item_context->label()) {
							$value = $item->adjValue();	
							push(@row_elements, $item->adjValue());
						}	
					}	
					if (!$value) {
						push(@row_elements, '&nbsp;');
					}	
				}	
				$table->addRow($row, @row_elements);	
			}
		}	
	}	
	
	&set_row_labels($self, $table, $uri);	

	#return $table->as_text();
	return $table;
}


sub make_land_table() {
	my ($self) = @_;
	my $uri = $self->{'uri'};	
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
	my $table = HTML::Table->new(-border => 1);

	my @row_elements;
	my @col_elements;
	my $hcubes = &get_hypercubes($self);
	for my $hypercube (@{$hcubes}) {	
		my $tmp_row = &get_row_elements($self, $hypercube);
		push(@row_elements, @{$tmp_row});	
		my $tmp_cols = &get_domain_names($self, $hypercube);
		push(@col_elements, @{$tmp_cols});	
	}	

	#$table->addRow('&nbsp;', @col_elements);
	$table->addHeader('&nbsp;', @col_elements); 	

	for my $e (@row_elements) {
		$table->addRow($e);	
	}

	my $col_counter = 2;	
	for my $domain ( @col_elements ) {
		my $items = &get_member_items($self, $domain, \@row_elements); 
		my $row_nums = $table->getTableRows();	

		my $item_counter = 0;	
		for (my $i = 2; $i <= $row_nums; $i++) {
			$table->setCell($i, $col_counter, $items->[$item_counter]);
			$item_counter++;
		}
		$col_counter++;
	}

	#Set the row level labels 
	#my $count = 2;	
	#for my $label (@row_elements) {
	#	my $prefLbl = $label->{'prefLabel'};
	#	my $id = $table->getCell($count, 1);
	#	my $label = $tax->get_label($id, $prefLbl);
	#	$table->setCell($count, 1, $label);
	# $count++;
	#}

	&set_row_labels($self, $table, $uri);	

	#Set the labels for the column headers 	
	my $num_cols = $table->getTableCols();	
	for (my $i = 2; $i <= $num_cols; $i++) {
		my $id = $table->getCell(1,$i);
		my $label = $tax->get_label($id);	
		$table->setCell(1, $i, $label);	
	}

	#return $table->getTable();
	return $table;
}

sub set_row_labels() {
	my ($self, $table) = @_;
	my $uri = $self->{'uri'};	
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
#	my @p_arcs = @{$self->{'pre_arcs'}}; 
	my $p_arcs = $tax->get_arcs('pre', $uri);


	#TODO Deal with different preferred labels for the same id in the same table
	#this code just takes the first one for every instance.
	for (my $i = 1; $i <= $table->getTableRows; $i++) {
		#my $id = $table->getCell($i,1);
		my $id = $table->label($i); 	
		$id =~ s/\:/\_/;	
		for (my $k = 0; $k < @{$p_arcs}; $k++) {
				if ($id eq $p_arcs->[$k]->to_short()) {
				#Get the label delete the entry from the the array
					my $label = $tax->get_label($id, $p_arcs->[$k]->prefLabel());				
					$table->label($i, $label);	
					#$table->setCell($i, 1, $label);	
					#delete $p_arcs[$k];	
			}
		}
	}

}


sub get_domain_item() {
	my ($self,  $domain, $id ) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
	
	$id =~ s/\_/\:/;

	my $all_contexts = $xbrl_doc->get_all_contexts();

	my @dom_contexts;

	for my $context_id (keys %{$all_contexts}) {
		my $context = $all_contexts->{$context_id};
		#my $dimension = $context->get_dimension($domain); 	
		my @tmp_array;
		push(@tmp_array, $domain);	
		my $dimension = $context->check_dims(\@tmp_array);	
		if ($dimension ) { 
			push(@dom_contexts, $context);	
		}	
	}

	my $all_items = $xbrl_doc->get_all_items();
	my @dom_items;	
	
	for my $item (@{$all_items}) {
			if ($id eq $item->name()) {
				push(@dom_items, $item);
			}
	}	


	my @out_array;

	for my $item (@dom_items) {
		for my $context (@dom_contexts) {	
			my $item_context = $all_contexts->{$item->context()};	
						if ($item_context->id() eq $context->id()) {
							push(@out_array, $item);	
						}
						#my $val = $context->endDate()->cmp($item_context->endDate()); 
						#if ($val == 0) {	
						#push(@out_array, $item);
						#}
			}
		}
	return \@out_array;
}

sub get_member_items() {
	my ($self, $domain, $id_list) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
		
	my @e_ids;
	#move the name/id to the @e_ids array 
	for my $thingie (@{$id_list}) {
					push(@e_ids, $thingie);
					#push(@e_ids, $thingie->{'id'});
	}

	#find contexts specifically linked to that domain	
	my $contexts = $xbrl_doc->get_all_contexts();
	my @domain_contexts;
	for my $context_id (keys %{$contexts}) {
		my $context = $contexts->{$context_id}; 
		my $dimension = $context->get_dimension($domain);	
		
		if ($dimension) {
			push(@domain_contexts, $context);	
		}
	}

	my $all_items = $xbrl_doc->get_all_items();

	my @domain_items;

	#this gets rid of duplicate ids.  Not sure why there are dups 
	my %seen = ();
	my @uniq = ();
	foreach my $id (@e_ids) {
    unless ($seen{$id}) {
        $seen{$id} = 1;
        push(@uniq, $id);
    }
	}

	my $sorted_contexts = &sort_contexts($self, \@domain_contexts);

	#get the item value for that id and context	
	my %data_struct;
	for my $uni (@uniq) {
		#print $_->id() . "\n";
		my @items;	
		for my $context (@{$sorted_contexts}) {
			my $item = &get_item($self, $uni, $context->id());
			if ($item) {	
				push(@items, $item);	
			#	print "\t" . $item->name() . "\t" . $item->value() . "\n";
			}	
			else {
							#warn "No item found for $uni with domain $domain at: " . $context->endDate() . "\n"
			}
		}
		$data_struct{$uni} = \@items;	
	}
	
	my @out_array;

	#iterate through the results and create an array of values or blanks
	for my $label (@e_ids) {
		my $items = $data_struct{$label};
		my $value = shift(@{$items});	
		if ($value) {	
			#print "$label\t" . $value->name() . "\t" . $value->value() . "\n";	
			push(@out_array, $value->adjValue());	
		}	
		else {
			push(@out_array, '&nbsp;');	
		}
	}
	
	return \@out_array;
}

sub sort_contexts() {
	#take a array ref of contexts and sort by end date	
	my ($self, $context_list) = @_;
	my $xbrl_doc = $self->{'xbrl'};	
	my @sorted = sort { $a->endDate()->cmp($b->endDate()) } @{$context_list}; 
	return \@sorted;

}


sub get_item() {
	my ($self, $item_id, $context_id) = @_;
	my $xbrl_doc = $self->{'xbrl'};	
	$item_id =~ s/\_/\:/;

	my $all_items = $xbrl_doc->get_all_items();

	my $search_context = $xbrl_doc->get_context($context_id);


	for my $item (@{$all_items}) {
		my $item_context = $xbrl_doc->get_context($item->context());	
		if (($item_context->id() eq $search_context->id()) && ($item->name() eq $item_id)) {
		#the following doesn't work
		#you end up with the same value across each cell in row	
		#if (($item_context->endDate()->cmp($search_context->endDate())) && ($item->name() eq $item_id)) {
			return $item;	
		}
	}
	return undef;
}

sub get_free_items() {
	#take an element id and return and array ref 
	#of all the items that aren't associated with a domain
	my ($self, $id) = @_; 
	
	my $xbrl_doc = $self->{'xbrl'};	
	$id =~ s/\_/\:/;

	my $all_items = $xbrl_doc->get_all_items();

	my @out_items;
	for my $item (@{$all_items}) {
		if ($item->name() eq $id) {
			my $item_context = $xbrl_doc->get_context($item->context());
			if (! $item_context->has_dim()) {
				push(@out_items, $item);
			}	
		}		
	}
	
	return \@out_items;

}


sub get_domain_names() {
	#take the uri and return an array of col elements + names in anon hash 	
	#for landscape dimension tables  
	my ($self, $hcube) = @_;
	my $xbrl_tax = $self->{'xbrl'}->get_taxonomy();
	my $uri = $self->{'uri'};	
	#my ($self, $type, $uri) = @_;
	my $arcs = $xbrl_tax->get_arcs('def', $uri );   
	my @top_domains;
	my @sub_domains;
	my @middle_domains;

	unless($arcs) { return undef; } 

		my $arc_all;	
		my $dimension_default;
		my $dimension_domain;	
		
		for my $arc (@{$arcs}) {
			if ( ($arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/all') && ($arc->to_short() eq $hcube->from_short() ) ) {
				$arc_all = $arc;	
			}	
			elsif ( ($arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/dimension-domain') && ( $arc->from_short() eq $hcube->to_short() )) {
				$dimension_domain = $arc;
			}	
			elsif ( ( $arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/dimension-default' ) && ($hcube->to_short() eq $arc->from_short() ) ) {
				$dimension_default = $arc;
			}
		}	
		for my $arc (@{$arcs}) {
			if (($arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/domain-member') &&   ($arc->from_short() eq $arc_all->from_short() )) {
						push(@sub_domains, $arc->to_short());	
			}
			elsif ($arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/domain-member') { 
			#elsif (($arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/domain-member') &&   ($arc->from_short() eq $dimension_domain->to_short() )) {
							#push(@top_domains, $arc->to_short());
				push(@middle_domains, $arc);	
			}	
		}	

		my %unique = ();	
		my @arc_array;	
		&test_recursion($dimension_domain->to_short(), \@middle_domains, \%unique, \@arc_array);	

	my @ordered_array = sort { $a->order() <=> $b->order() } @arc_array;	
	my @out_array;

	for my $arc (@ordered_array) {
		push(@out_array, $arc->to_short());
	}
	

	return \@out_array; 
}

sub test_recursion() {
	my ($domain_finder, $arc_queue, $unique_hash, $final_array  ) = @_;
	

	for my $incoming (@{$arc_queue}) {
		if ($domain_finder eq $incoming->from_short) {
			if (! $unique_hash->{$incoming->to_short} ) {
				$unique_hash->{$incoming->to_short}++;
				push(@{$final_array}, $incoming);	
				&test_recursion($incoming->to_short(), $arc_queue, $unique_hash, $final_array);	
			}	
		}
	}
}



sub get_row_elements() {
	#take a uri and return an array of anonymous hash with element id + pref label
	#for landscape dimension tables 	
	my ($self, $hcube) = @_;
	#my $arcs = $self->{'def_arcs'};
	my $xbrl_tax = $self->{'xbrl'}->get_taxonomy();
	my $uri = $self->{'uri'};	
	#my ($self, $type, $uri) = @_;
	my $arcs = $xbrl_tax->get_arcs('def', $uri );   
	
	
	my $arc_all;	
		my $dimension_default;
		my $dimension_domain;	
		
		for my $arc (@{$arcs}) {
			if ( ($arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/all') && ($arc->to_short() eq $hcube->from_short() ) ) {
				$arc_all = $arc;	
			}	
			elsif ( ($arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/dimension-domain') && ( $arc->from_short() eq $hcube->to_short() )) {
				$dimension_domain = $arc;
			}	
			elsif ( ( $arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/dimension-default' ) && ($hcube->to_short() eq $arc->from_short() ) ) {
				$dimension_default = $arc;
			}
		}	
						#if (($arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/domain-member') &&   ($arc->from_short() eq $arc_all->from_short() )) {

	my @dm_arcs;
	for my $arc (@{$arcs}) {	
		if ($arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/domain-member') { 
			push(@dm_arcs, $arc);
		}
	}
	my %unique_list;
	my @arclist;

	&test_recursion($arc_all->from_short(), \@dm_arcs, \%unique_list, \@arclist);	

#	my @ordered_array = sort { $a->order() <=> $b->order() } @arclist;	
	my @out_array;

	#for my $arc (@ordered_array) {
	for my $arc (@arclist) {
		push(@out_array, $arc->to_short());
	}


	return \@out_array;	
}



sub is_landscape() {
	my ($self)  = @_;
	my $def_uri = $self->{'uri'};	
	my $xbrl_doc = $self->{'xbrl'};	
	my $tax = $xbrl_doc->get_taxonomy();
#	my $preLB = $tax->pre();
	my $start = 'http://www.xbrl.org/2003/role/periodStartLabel'; 
	my $end = 'http://www.xbrl.org/2003/role/periodEndLabel'; 

	my $arcs = $tax->get_arcs('pre', $def_uri);

	for my $arc (@{$arcs}) {
		if ($arc->prefLabel) {
		 	if (($arc->prefLabel eq $start) or ($arc->prefLabel eq $end) ) {
				return 'true';
			}
		}
	}


}




sub get_header_contexts() {
	my ($self) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	
	my $xbrl_tax = $self->{'xbrl'}->get_taxonomy();
	my $uri = $self->{'uri'};	
	#my ($self, $type, $uri) = @_;
	my $arcs = $xbrl_tax->get_arcs('def', $uri );   
	

#	my $arcs = $self->{'def_arcs'}; 
	
	my $all_contexts = $xbrl_doc->get_all_contexts();	

	my @dimensions;

		for my $arc (@{$arcs}) {
			if ($arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/dimension-domain') {
				push(@dimensions, $arc->from_short()); 
			}
		}

	my @dim_contexts;
	for my $dim (@dimensions) {
		for my $cont_id (keys %{$all_contexts}) {
			my $context = $all_contexts->{$cont_id};
			if (($context) && ($context->is_dim_member($dim))) {
				push(@dim_contexts, $context);
			}	
		}	
	}	

	my @item_names;
	for my $arc(@{$arcs}) {
		if ($arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/domain-member') {
			push(@item_names, $arc->to_short()); 
		}
	}
	my @item_contexts;
	my $all_items = $xbrl_doc->get_all_items();			
	my @items;	
	for my $item_name (@item_names) {
		$item_name =~ s/\_/\:/g;	
		for my $item (@{$all_items}) {
			if ($item_name eq $item->name()) {
				my $item_context = $all_contexts->{$item->context()};
				push(@item_contexts, $item_context);	
			}
		}		
	}	
	
	my @table_contexts;
	for my $item_context (@item_contexts) {
		for my $dim_context (@dim_contexts) {	
			my $val = $item_context->endDate()->cmp($dim_context->endDate()); 
			if ($val == 0) {
				push(@table_contexts, $item_context);
			}	
		}	
	}


	my %seen = ();
	my @uniq = ();
	foreach my $context (@item_contexts) {
    unless ($seen{$context->label()}) {
        # if we get here, we have not seen it before
        $seen{$context->label()} = 1;
        push(@uniq, $context);
    }
	}


	#sort the buggers 
	my (@dur, @per) = ();
	for (@uniq) {
					#print "\t" . $_->label() . "\n";	
		if ($_->duration()) {
			push(@dur, $_);
		}
		else {
			push(@per, $_); 
		}
	}

	my @sorted_dur = sort { $a->duration() cmp $b->duration() 
																				|| 
													$b->endDate()->cmp($a->endDate()) } @dur;


	my @sorted_per = sort { $b->endDate()->cmp($a->endDate()) } @per; 
	my @out_array = ();
	push(@out_array, @sorted_dur);
	push(@out_array, @sorted_per); 
	return \@out_array;

}

sub get_def_section() {
	my ($self) = @_;
	#take the uri and return xml that includes all of the 
	#sections for that uri 
	my $uri = $self->{'uri'};	
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
	my @out_array;
	#push(@out_array, '&nbsp;');
	my $defLB = $tax->def(); 
	#TODO Need to improve this 	
	my $d_link = $defLB->findnodes("//*[local-name() = 'definitionLink'][\@xlink:role = '" . $uri . "' ]"); 

	unless ($d_link) { return undef };


	return $d_link;
}



sub get_hypercubes() {
	my ($self) = @_;
	my $xbrl_tax = $self->{'xbrl'}->get_taxonomy();
	my $uri = $self->{'uri'};	
	#my ($self, $type, $uri) = @_;
	my $arcs = $xbrl_tax->get_arcs('def', $uri );   
	
	#my $arcs = $self->{'def_arcs'};	
	my @hypercubes;	
				
	for my $arc (@{$arcs}) {
		if ( $arc->arcrole() eq 'http://xbrl.org/int/dim/arcrole/hypercube-dimension') {
						push(@hypercubes, $arc);						
		} 
	}

	return \@hypercubes;
}

=head1 XBRL::Dimension 

XBRL::Dimension - OO Module for Parsing XBRL Dimensions  

=head1 SYNOPSIS

  use XBRL::Dimension;

	my $dimension = XBRL::Dimension->new($xbrl_doc, "http://fu.bar.com/role/DisclosureGoodwillDetails" );	
	
	
	$html_table = $dimension->get_xml_table(); 
  
	
=head1 DESCRIPTION

This module is part of the XBRL modules group and is intended for use with XBRL.

=over 4

=item new 

	my $dimension = XBRL::Dimension->new($xbrl_doc, "http://fu.bar.com/role/DisclosureGoodwillDetails" );	


Object constructor takes the xbrl document and the section URI as parameters.

=item get_xml_table

	$xml_table = $dimension->get_xml_table(); 

Returns a scalar containing an HTML representation of the 
				
=back

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




