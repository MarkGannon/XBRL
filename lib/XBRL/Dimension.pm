package XBRL::Dimension;

use strict;
use warnings;
use Carp;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

our $VERSION = '0.01';

sub new() {
	my ($class, $xbrl_doc, $uri) = @_;
	my $self = { xbrl => $xbrl_doc,
								uri => $uri };
	bless $self, $class;
	
	return $self;
}

sub get_html_table() {
	my ($self, $uri) = @_;
	
	my $table;
	if (&is_landscape($self, $uri)) {
			$table = &make_land_table($self, $uri); 	
		}
		else {	
			$table = 	&make_port_table($self, $uri);
		}	
	
	return $table;
}


sub make_port_table() {
	my ($self, $uri) = @_; 
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
	my $table = HTML::Table->new(-border => 1);

	my $header_contexts = &get_header_contexts($self, $uri); 

	
	my @col_labels;
	for my $context (@{$header_contexts}) {
		push(@col_labels, $context->label());	
	}
	$table->addRow('&nbsp;', @col_labels); 	

	my $domain_names = &get_domain_names($self, $uri);	
	my $row_elements = &get_row_elements($self, $uri);  

	for my $domain (@{$domain_names}) {
		my $d_label = $tax->get_label($domain);	
		$table->addRow($d_label);	
		for my $thingie (@{$row_elements}) {
			my @row_items;	
			my $items = &get_domain_item($self, $domain, $thingie->{'id'});
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
			my $row_label = $tax->get_label($thingie->{'id'}, $thingie->{'pref'}); 	
			$table->addRow($row_label, @row_items);	
		}
	}

	return $table->getTable();
}


sub make_land_table() {
	my ($self, $uri) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();

	my $table = HTML::Table->new(-border => 1);

	my $row_elements = &get_row_elements($self, $uri);
	my $col_elements = &get_domain_names($self, $uri);
	$table->addRow('&nbsp;', @{$col_elements});



	for my $e (@{$row_elements}) {
		$table->addRow($e->{'id'});	
	}

	my $col_counter = 2;	
	for my $domain ( @{$col_elements} ) {
		my $items = &get_member_items($self, $domain, $row_elements); 
		my $row_nums = $table->getTableRows();	

		my $item_counter = 0;	
		for (my $i = 2; $i <= $row_nums; $i++) {
			$table->setCell($i, $col_counter, $items->[$item_counter]);
			$item_counter++;
		}
		$col_counter++;
	}

	#Set the row level labels 
	my $count = 2;	
	for my $label (@{$row_elements}) {
		my $prefLbl = $label->{'prefLabel'};
		my $id = $table->getCell($count, 1);
		my $label = $tax->get_label($id, $prefLbl);
		$table->setCell($count, 1, $label);
		$count++;
	}


	#Set the labels for the column headers 	
	my $num_cols = $table->getTableCols();	
	for (my $i = 2; $i <= $num_cols; $i++) {
		my $id = $table->getCell(1,$i);
		my $label = $tax->get_label($id);	
		$table->setCell(1, $i, $label);	
	}

	return $table->getTable();
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
		my $dimension = $context->get_dimension($domain); 	
		if ($dimension ) { 
			#print "context has $dimension\n";	
			push(@dom_contexts, $context);	
		}	
	}


	my $all_items = $xbrl_doc->get_all_items();
	my @dom_items;	
	for my $context (@dom_contexts) {	
		for my $item (@{$all_items}) {
			#print $context->id() . "\t" . $item->context() . "\t" . $item->name() . "\t" . $id ."\n";	
			if (($context->id() eq $item->context()) && ($item->name() eq $id)) {
				push(@dom_items, $item);
			}
		}
	}
	
	return \@dom_items;
}

sub get_member_items() {
	my ($self, $domain, $id_list) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
		
	my @e_ids;

	for my $thingie (@{$id_list}) {
		push(@e_ids, $thingie->{'id'});
	}

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


	my %seen = ();
	my @uniq = ();
	foreach my $id (@e_ids) {
    unless ($seen{$id}) {
        $seen{$id} = 1;
        push(@uniq, $id);
    }
	}

	my $sorted_contexts = &sort_contexts($self, \@domain_contexts);

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
		}
		$data_struct{$uni} = \@items;	
	}
	
	my @out_array;

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
	
	for my $item (@{$all_items}) {
		if (($item->context() eq $context_id) && ($item->name() eq $item_id)) {
			return $item;	
		}
	}
	return undef;
}


sub get_domain_names() {
	#take the uri and return an array of col elements + names in anon hash 	
	#for landscape dimension tables  
	my ($self, $uri) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
	my @out_array;
	#push(@out_array, '&nbsp;');
	my $defLB = $tax->def(); 
	
	my $d_link = $defLB->findnodes("//*[local-name() = 'definitionLink'][\@xlink:role = '" . $uri . "' ]"); 

	unless ($d_link) { return undef };

	my $loc_list = $d_link->[0]->getChildrenByLocalName('loc');
	my $arc_list = $d_link->[0]->getChildrenByLocalName('definitionArc');	
		
	my %subsections = (); 

	my $dimension;

	for my $arc (@{$arc_list}) {
		if ($arc->getAttribute('xlink:arcrole') eq  'http://xbrl.org/int/dim/arcrole/dimension-domain') {
			$dimension = "true";
		}
		if (($dimension) && ($arc->getAttribute('xlink:arcrole') eq  'http://xbrl.org/int/dim/arcrole/domain-member')) {
			for my $loc (@{$loc_list}) {
				if ($loc->getAttribute('xlink:label') eq $arc->getAttribute('xlink:to') ) {
					my $element_uri = $loc->getAttribute('xlink:href');
					$element_uri =~ m/\#([A-Za-z0-9_-].+)$/; 	
					my $e_id = $1;
					push(@out_array, $e_id);
				}
			}

		}	
	}
	
	return \@out_array;
}



sub get_row_elements() {
	#take a uri and return an array of element id + pref label
	#for landscape dimension tables 	
	my ($self, $uri) = @_;
	my $xbrl_doc = $self->{'xbrl'};	
	my $tax = $xbrl_doc->get_taxonomy();	
	
	my $preLB = $tax->pre();

	my @out_array;
	
	my $p_link = $preLB->findnodes("//*[local-name() = 'presentationLink'][\@xlink:role = '" . $uri . "' ]"); 

	if ($p_link) {	

		my $loc_list = $p_link->[0]->getChildrenByLocalName('loc');
		my $arc_list = $p_link->[0]->getChildrenByLocalName('presentationArc');	
		
		
		my %subsections = (); 
		my @subsec_array = ();
		for (@{$loc_list}) {
			my $element_uri = $_->getAttribute('xlink:href');
			$element_uri =~ m/\#([A-Za-z0-9_-].+)$/; 	
			my $element_id = $1;
			my $element = $tax->get_elementbyid($element_id);
			unless ($element) { croak "can't find id for $element_id\n"; }	
			$subsections{$element_uri}++;
		}
				
		for my $loc (@{$loc_list}) {
			my $href = $loc->getAttribute('xlink:href');
			if (($subsections{$href}) && ($subsections{$href} > 0)) {
				push(@subsec_array, $href);
				delete $subsections{$href};
			}
		}
		
		for my $section (@subsec_array) {
			my @section_array = ();	
			#iterate through all the locs and find ones that match the section names
			for my $loc (@$loc_list) {
				my $xlink = $loc->getAttribute('xlink:href');
				if ($xlink eq $section) {
					my $loc_label = $loc->getAttribute('xlink:label');	
						for my $arc (@{$arc_list}) {
							my $arc_from = $arc->getAttribute('xlink:from');	
							my $arc_to = $arc->getAttribute('xlink:to');	
							
							if ($arc_from eq $loc_label ) { 	
								my $order = $arc->getAttribute('order');	
								my $pref_label = $arc->getAttribute('preferredLabel');	
								for my $el_loc (@{$loc_list}) {
									my $label = $el_loc->getAttribute('xlink:label');
									if ($arc_to eq $label) {
										my $el_link = $el_loc->getAttribute('xlink:href');
										$el_link =~ m/\#([A-Za-z0-9_-].+)$/; 		
										my $el_id = $1;	
										if (($el_id !~ /axis$/i) && ($el_id !~ m/abstract$/i) && ($el_id !~ m/member/i) 
										&& ($el_id !~ m/domain$/i) && ($el_id !~ m/lineitems/i)) {	
											push(@section_array, { section => $section,
																					order => $order,
																					element_id => $el_id,
																					pref => $pref_label } );
										}	
									}
								}
							}	
						}
				}
			}

		
		my @ordered_array = sort { $a->{'order'} <=> $b->{'order'} } @section_array;	
			for my $item (@ordered_array) {
				#$item->{'element_id'} =~ s/\:/\_/g;	
				#print "\t" . $item->{'order'} . "\t" . $item->{'element_id'} . "\n";
				my $e = $tax->get_elementbyid($item->{'element_id'});
				if (! $e ) {
					croak "Couldn't find element for: " . $item->{'element_id'} . "\n";
				}
				push(@out_array, { id => $item->{'element_id'}, 
													prefLabel => $item->{'pref'} } );  
			}
		}		

	}
	return \@out_array;
}
	


sub is_landscape() {
	my ($self, $def_uri) = @_;
	my $xbrl_doc = $self->{'xbrl'};	
	my $tax = $xbrl_doc->get_taxonomy();
	my $preLB = $tax->pre();

	my $p_link = $preLB->findnodes("//*[local-name() = 'presentationLink'][\@xlink:role = '" . $def_uri . "' ]"); 
	
	my $preArcs = $p_link->[0]->getChildrenByLocalName('presentationArc');
	
	for my $arc (@{$preArcs}) {
		my $label = $arc->getAttribute('preferredLabel');
		next unless ($label);
		if (($label eq  'http://www.xbrl.org/2003/role/periodStartLabel') or 
		($label eq  'http://www.xbrl.org/2003/role/periodEndLabel') ) {
			return "true";
		}
	}
}




sub get_header_contexts() {
	my ($self, $uri) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();

	print "Getting Headers for: $uri \n";

	my $defLB = $tax->def();

	my $d_link = $defLB->findnodes("//*[local-name() = 'definitionLink'][\@xlink:role = '" . $uri . "' ]"); 

	unless ($d_link) { return undef };


	my @loc_links = $d_link->[0]->getChildrenByLocalName('loc'); 
	my @arc_links = $d_link->[0]->getChildrenByLocalName('definitionArc'); 



	my @context_ids = ();


	my @dim_names;

	for my $arc (@arc_links) {
		my $arcrole = $arc->getAttribute('xlink:arcrole');
		if ( $arcrole eq 'http://xbrl.org/int/dim/arcrole/dimension-domain' ) {

#		if ( $arcrole eq 'http://xbrl.org/int/dim/arcrole/dimension-default' ) {
			my $link_from = $arc->getAttribute('xlink:from');
			for my $loc (@loc_links) {
				if ( $loc->getAttribute('xlink:label') eq $link_from ) {
						my $whole_uri = $loc->getAttribute('xlink:href');
						$whole_uri =~ m/\#([A-Za-z0-9_-].+)$/; 	 
						my $dim = $1;	
						push(@dim_names,$dim);	
				}
			}
		}
	}


	my $domains = &get_domain_names($self, $uri);

	my $all_contexts = $xbrl_doc->get_all_contexts();	

	my @dim_contexts = ();
	#TODO add warning for case where there are no 
	#contexts for a specified dimension 
	for my $dim_name (@dim_names) {	
		print "\tDimension: $dim_name\n";	
		for my $domain_name (@{$domains}) {
			$domain_name =~ s/\_/:/;	
			print "\t\tDomain Name: $domain_name\n";	
			for my $context_id (keys %{$all_contexts}) {
				my $context = $all_contexts->{$context_id};
				if ($context->is_dim_member($dim_name)) {
					my $value = $context->get_dim_value($dim_name); 
					#print "\t\t\tValue: $value\n";	
					if ($value eq $domain_name) {
						print "\t\t\t matched \n";	
						push(@dim_contexts, $context);
					}
				}
				
			}
		}
	
	
	}
	
	my %seen = ();
	my @uniq = ();
	foreach my $context (@dim_contexts) {
    unless ($seen{$context->label()}) {
        # if we get here, we have not seen it before
        $seen{$context->label()} = 1;
        push(@uniq, $context);
    }
	}


	#sort the buggers 
	my (@dur, @per) = ();
	for (@uniq) {
		print "\t" . $_->label() . "\n";	
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




1;





