package XBRL::Table;

use strict;
use warnings;
use Carp;
use HTML::Table;

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
	my $self = { xbrl => $xbrl_doc}; 
	bless $self, $class;



	return $self;
}


sub is_textblock() {
	my ($self, $uri) = @_;

	#print "Checking $uri\n";

	my $arcs = &get_pres_arcs($self, $uri);
	
	if ($arcs) {	
		my $tax = $self->{'xbrl'}->get_taxonomy();
		for my $arc (@{$arcs}) {	
			my $e_id = $arc->{'element'};
	
			my $element = $tax->get_elementbyid($e_id);
			if ($element->type() eq 'us-types:textBlockItemType') {
				my $item_id = $element->id();
				$item_id =~ s/\_/\:/;
				my $items = $self->{'xbrl'}->get_item_all_contexts($item_id);
				if ($items->[0]) {	
					return $items->[0]->value();
				}	
			}
		}	
	}
}



sub get_pres_arcs() {
	my ($self, $uri) = @_;
	my $xbrl_tax = $self->{'xbrl'}->get_taxonomy();	
	
	my $presLB = $xbrl_tax->pre();
	my $p_link = $presLB->findnodes("//*[local-name() = 'presentationLink'][\@xlink:role = '" . $uri . "' ]"); 

	unless ($p_link) { return undef }

	my @loc_links = $p_link->[0]->getChildrenByLocalName('loc'); 
	my @arc_links = $p_link->[0]->getChildrenByLocalName('presentationArc'); 
	
	my @arcs = ();
	for my $arc (@arc_links) {
		my $element = ();
		for my $loc (@loc_links) {
			if ($loc->getAttribute('xlink:label') eq $arc->getAttribute('xlink:to') ) {
			 my $uri = $loc->getAttribute('xlink:href');	
				$uri =~ m/\#([A-Za-z0-9_-].+)$/; 	
				$element = $1;	
			}
		}


		push(@arcs, { arcrole => $arc->getAttribute('xlink:arcrole'),
								order => $arc->getAttribute('order'),
								from => $arc->getAttribute('xlink:from'),
								to => $arc->getAttribute('xlink:to'),
								element => $element,
								preferredLabel => $arc->getAttribute('preferredLabel') } );

	}


	return \@arcs;
}



sub get_html_table() {
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


	my $row_elements = &get_row_elements($self, $uri);


	for my $row (@{$row_elements}) {
		my $element = $tax->get_elementbyid($row->{'id'});	
		my $row_items = &get_norm_row($self, $element, $header_contexts);	
		my $label = $tax->get_label($row->{'id'}, $row->{'pref'});	
		#$table->addRow($row->{'id'}, @{$row_items});	
		if ($row_items->[0]) {	
			$table->addRow($label, @{$row_items});	
		}	
	}
	


	return $table->getTable();

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

	my $arcs = &get_pres_arcs($self, $uri);

	my $all_items = $xbrl_doc->get_all_items();

	my @contexts;

	for my $arc (@{$arcs}) 	{
		for my $item (@{$all_items}) {
			my $arc_id = $arc->{'element'};
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
	#print "Sections for $uri \n";	
	my $sub_secs = &get_subsects($self, $uri);
	my $loc_list = &get_pres_locs($self, $uri);
	my $arc_list = &get_pres_arcs($self, $uri);
	my @out_array;

		for my $section (@{$sub_secs}) {
			#print "Working on subsect:\t$section\n";	
			my @section_array = ();	
			#iterate through all the locs and find ones that match the section names
			for my $loc (@{$loc_list}) {
				my $xlink = $loc->{'href'};  #getAttribute('xlink:href');
				if ($xlink eq $section) {
					my $loc_label = $loc->{'label'}; #getAttribute('xlink:label');	
						for my $arc (@{$arc_list}) {
							my $arc_from = $arc->{'from'}; #getAttribute('xlink:from');	
							my $arc_to = $arc->{'to'}; #getAttribute('xlink:to');	
							
							if ($arc_from eq $loc_label ) { 	
								my $order = $arc->{'order'}; #getAttribute('order');	
								my $pref_label = $arc->{'pref'}; # getAttribute('preferredLabel');	
								for my $el_loc (@{$loc_list}) {
									my $label = $el_loc->{'label'}; #getAttribute('xlink:label');
									if ($arc_to eq $label) {
										my $el_link = $el_loc->{'href'}; #getAttribute('xlink:href');
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

	
	return \@out_array;
}


sub get_subsects() {
	my ($self, $uri) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	#my $xbrl_tax = $self->{'xbrl'}->get_taxonomy();	
	my $tax = $xbrl_doc->get_taxonomy();
	#Emy $tax = $self->{'xbrl'}->get_taxonomy();	
	my @out_array;

	my $pres_arcs = &get_pres_arcs($self, $uri); 
	my $pres_locs = &get_pres_locs($self, $uri);

	my @all_uris;
	for my $arc (@{$pres_arcs}) {
		for my $loc (@{$pres_locs}) {
			if ($arc->{'from'} eq $loc->{'label'}) {
				push(@all_uris, $loc->{'href'});
			}
		}
	
	}
	
	my %seen = ();
	my @uniq = ();
	foreach my $uri (@all_uris) {
    unless ($seen{$uri}) {
        # if we get here, we have not seen it before
        $seen{$uri} = 1;
        push(@uniq, $uri);
    }
	}


	return \@uniq; 
}

sub get_pres_locs() {
	my ($self, $uri) = @_;
	my $xbrl_doc = $self->{'xbrl'};
	my $tax = $xbrl_doc->get_taxonomy();
	my $presLB = $tax->pre();
	my @out_array;

	my $p_link = $presLB->findnodes("//*[local-name() = 'presentationLink'][\@xlink:role = '" . $uri . "' ]"); 

	
	#TODO should be a warning 	
	#croak "unable to get a presentation link for $uri \n" unless ($p_link);

	if ($p_link->[0]) {
	my $loc_list = $p_link->[0]->getChildrenByLocalName('loc');

		for my $loc (@{$loc_list}) {
			push(@out_array, { href => $loc->getAttribute('xlink:href'),
											label => $loc->getAttribute('xlink:label') } );

		}
	}
	return \@out_array;
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




