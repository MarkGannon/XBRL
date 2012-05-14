package XBRL::Table;

use strict;
use warnings;
use Carp;
use HTML::Table;
use XBRL::Arc;
use Data::Dumper;
use XBRL::TableXML;

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

	if (!$uri) {
		$uri = $self->{'uri'};	
	}

	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
	
#	my $table = HTML::Table->new(-border => 1);
	my $table = XBRL::TableXML->new(); 


	my $header_contexts = &get_header_contexts($self, $uri); 

	my @col_labels;
	for my $context (@{$header_contexts}) {
		push(@col_labels, $context->label());	
	}
	#$table->addRow('&nbsp;', @col_labels); 	
	$table->addHeader('&nbsp;', @col_labels); 	


	my $row_elements = &get_row_elements($self, $uri);


	for my $row (@{$row_elements}) {
		my $element = $tax->get_elementbyid($row->to_short());	
		my $row_items = &get_norm_row($self, $element, $header_contexts);	
		my $label = $tax->get_label($row->to_short(), $row->prefLabel()); 
		#$table->addRow($row->{'id'}, @{$row_items});	
		if ($row_items->[0]) {	
			$table->addRow($label, @{$row_items});	
		}	
	}

	#eturn $table->getTable();
	#return $table->as_text();
	return $table;
}



sub get_norm_row() {
	my ($self, $element, $headers) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	my @out_array;
	#push(@out_array, $element->label());	

	my $item_id = $element->id();
	$item_id =~ s/\_/\:/;

	my $items = $xbrl_doc->get_item_all_contexts($item_id); 
	if (!$items) {
		return undef;
	}
	
	for my $header_context (@{$headers}) {
		my $value;	
		for my $item (@{$items}) {
			my $item_context = $xbrl_doc->get_context($item->context());
			next if $item_context->has_dim();	
			if ($header_context->label() eq $item_context->label()) {
				$value = $item->adjValue();	
			#	$row = $row . "<td>" . $value . "</td>\n";
				push(@out_array, $value);	
			}
		}
		if (!$value) {
				#$row = $row . "<td>" . '&nbsp;'  . "</td>\n";
				push(@out_array, '&nbsp');
		}
	}

	return \@out_array;
}


sub get_uniq_sections() {
	my ($self, $nodes ) = @_;


	my @loc_links = $nodes->getChildrenByLocalName('loc'); 
	my @arc_links = $nodes->getChildrenByLocalName('definitionArc'); 

	my %subsections = ();

	for my $loc (@loc_links) {
		for my $arc (@arc_links) {
			if ( $loc->getAttribute('xlink:label') eq $arc->getAttribute('xlink:from') ) {
				$subsections{$loc->getAttribute('xlink:href')}++;
			}
		}
	}
	
	my @out_array;
	for my $loc (@loc_links) {
		my $href = $loc->getAttribute('xlink:href');	
		if ($subsections{$href} ) {
			push(@out_array, $href);	
			delete $subsections{$href};	
		}
	}

	return (\@out_array);
}


sub get_headers() {
	my ($self, $nodes) = @_;
	my $xbrl_doc = $self->{'xbrl'};

	my @loc_links = $nodes->getChildrenByLocalName('loc'); 
	my @arc_links = $nodes->getChildrenByLocalName('definitionArc'); 



	my @context_ids = ();

	my $dim;

	for my $arc (@arc_links) {

		my $arcrole = $arc->getAttribute('xlink:arcrole');
		if ( $arcrole eq 'http://xbrl.org/int/dim/arcrole/dimension-default' ) {
			my $link_from = $arc->getAttribute('xlink:from');
			for my $loc (@loc_links) {
				if ( $loc->getAttribute('xlink:label') eq $link_from ) {
						my $whole_uri = $loc->getAttribute('xlink:href');
						$whole_uri =~ m/\#([A-Za-z0-9_-].+)$/; 	 
						$dim = $1;	
				}
			}
		}
		elsif ( $arcrole eq 'http://xbrl.org/int/dim/arcrole/domain-member' ) {
			my $link_to = $arc->getAttribute('xlink:to');
			for my $loc (@loc_links) {
				if ($loc->getAttribute('xlink:label') eq $link_to) {
						my $whole_uri = $loc->getAttribute('xlink:href');
						$whole_uri =~ m/\#([A-Za-z0-9_-].+)$/; 	 
						my $item_id = $1;
						$item_id =~ s/\_/\:/;	
						my $items = $xbrl_doc->get_item_all_contexts($item_id);  
							for my $item (@{$items}) {
								push(@context_ids, $item->context());	
							}
				}

			}

		}
			

	}

	my @item_contexts = ();

	for my $context_id (@context_ids) {
		my $context = $xbrl_doc->get_context($context_id);
		push(@item_contexts, $context);	
	}

	if ($dim) {
		my $dim_contexts = $xbrl_doc->get_dim_contexts($dim);
		push(@item_contexts, @{$dim_contexts});
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

sub get_header_contexts() {
	my ($self, $uri) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
	
	#my $arcs = &get_pres_arcs($self, $uri);
	
	my $arcs = $tax->get_arcs("pre", $uri);  
	#print "First get_arcs dump:\n";
	#print Dumper($arcs);

	my $all_items = $xbrl_doc->get_all_items();

	my @contexts;

	for my $arc (@{$arcs}) 	{
		for my $item (@{$all_items}) {
			#my $arc_id = $arc->{'element'};
			my $arc_id = $arc->to_short(); 
			$arc_id =~ s/\_/:/;	
			if ($arc_id eq $item->name()) {
				my $cont_id = $item->context();
				my $context = $xbrl_doc->get_context($cont_id);
				push(@contexts, $context);	
			}
		}
	}


	
	my %seen = ();
	my @uniq = ();
	foreach my $context (@contexts) {
    unless ($seen{$context->label()}) {
        # if we get here, we have not seen it before
        $seen{$context->label()} = 1;
        push(@uniq, $context);
    }
	}


	#sort the buggers 
	my (@dur, @per) = ();
	for (@uniq) {
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

sub get_row_elements() {
	#take a uri and return an array of element id + pref label
	#for landscape dimension tables 	
	my ($self, $uri) = @_;
	my $xbrl_doc = $self->{'xbrl'};	
	my $tax = $xbrl_doc->get_taxonomy();	
	my $sub_secs = &get_subsects($self, $uri);
	my $arcs = $tax->get_arcs("pre", $uri);	
	
	my @section_array = ();	

		for my $section (@{$sub_secs}) {

			for my $arc (@{$arcs}) {
				if ($arc->from_full() eq $section) {
					push(@section_array, $arc);
				}
			}
		}


	my @ordered_array = sort { $a->order() <=> $b->order() } @section_array;	

	
	return \@ordered_array;
}


sub get_subsects() {
	my ($self, $uri) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	my $xbrl_tax = $xbrl_doc->get_taxonomy();	
	
	my @out_array;

	my $pres_arcs = $xbrl_tax->get_arcs("pre", $uri ); 

	my %seen = ();
	my @uniq = ();
	foreach my $arc (@{$pres_arcs}) {
		unless ( $seen{ $arc->from_full() } ) {
        # if we get here, we have not seen it before
        $seen{ $arc->from_full() } = 1;
        push(@uniq, $arc->from_full());
    }
	}

	return \@uniq; 
}


=head1 XBRL::Table 

XBRL::Table - OO Module for creating HTML Tables from XBRL Sections   

=head1 SYNOPSIS

  use XBRL::Table;

	my $table = XBRL::Table->new($xbrl_object); 

	my $html_table = $table->get_html_table($section_id); 

	
=head1 DESCRIPTION

This module is part of the XBRL modules group and is intended for use with XBRL.

new($xbrl_doc) -- Object constructor that takes  an XBRL object.

get_html_report($section_role_uri) -- Takes a section role URI 
			(e.g http://fu.bar.com/role/DisclosureGoodwill) and returns an 
			HTML Table of that section  
				

=head1 AUTHOR

Mark Gannon <mark@truenorth.nu>

=head1 SEE ALSO

Modules: XBRL XBRL::Dimension  

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




