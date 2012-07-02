package XBRL::Context;

use strict;
use warnings;
use Date::Manip::Date;
use Carp;
use Data::Dumper;
use POSIX;
use Math::Round qw(round);

use base qw( Class::Accessor );

XBRL::Context->mk_accessors( qw(id scheme identifier startDate endDate label dimension duration) );
		
		
sub new() {
	my ($class, $xml) = @_;
	my $self = {};
	bless $self, $class;

	if ($xml) {
		&parse($self, $xml);
	}

	return $self;
}


sub parse() {
	my ($self, $in_xml) = @_;
#getElementsByLocalName($localname)
	$self->{'id'} = $in_xml->getAttribute( 'id' );
	my @nodes = $in_xml->getElementsByLocalName('identifier'); 
	#print $nodes[0]->toString() . "\n";	
	$self->{'scheme'} = $nodes[0]->getAttribute( 'scheme' );
	$self->{'identifier'} = $nodes[0]->textContent();
	my @starts = $in_xml->getElementsByLocalName('startDate'); 

	my $start_date = Date::Manip::Date->new();
	$start_date->config("language", "English", "tz", "America/New_York");


	if ($starts[0]) {
	#	$self->{'startDate'} = $starts[0]->textContent(); 
		$start_date->parse($starts[0]->textContent()); 
		$self->{'startDate'} = $start_date; 
	}	
	
	my @ends = $in_xml->getElementsByLocalName('endDate');
	my $end_date = $start_date->new_date();

	if ($ends[0]) {
		#$self->{'endDate'} = $ends[0]->textContent();
		$end_date->parse($ends[0]->textContent());	
		$self->{'endDate'} = $end_date;  
		
	}

	my @times = $in_xml->getElementsByLocalName('instant');
	my $instant_date = $start_date->new_date();

	if ($times[0]) {
		#$self->{'instant'} = $times[0]->textContent();
		$instant_date->parse($times[0]->textContent());
		$self->{'endDate'} = $instant_date; 
	}

	if (($self->{'endDate'}) && (!$self->{'startDate'})) {
		#$self->{'label'} = $self->{'instant'};
		$self->{'label'} = $instant_date->printf("%B %d, %Y");  
	}
	else {
		my $subtract = 0;
		my $mode = "approx";
		my $delta = $self->{'startDate'}->calc($self->{'endDate'}, $subtract, $mode); 
	
		#FIXME there is some Date::Manip weirdness around weeks and months	
		my $delta_years = $delta->printf("%yv");	
		my $delta_month = $delta->printf("%Mv");
		my $delta_weeks = $delta->printf("%wv");
		$delta_month = $delta_month + $delta_years * 12 + $delta_weeks / 4;
		$self->{'duration'} = $delta_month;

		my $end_of_time = $self->{'endDate'}->printf("%B %d, %Y");  
		#round the delta month up.
		$delta_month = &round($delta_month);
		$self->{'label'} = "$delta_month months ending $end_of_time";	
	
	}

	#add the dimension 
	#FIXME  Need to deal properly with the whole dimension thing.  	
	my @dim_nodes = $in_xml->getElementsByLocalName('explicitMember'); 
	my @dim_array = ();	
	for my $dim (@dim_nodes) {	
		my $dim_name = $dim->getAttribute('dimension');  
		my $val = $dim->textContent();	
		push(@dim_array, { dim => $dim_name, val => $val }); 	
	}
		$self->{'dimension'} = \@dim_array; 
	

}

sub get_dimension() {
	#take a domain and return the context's dimension for that domain	
	my ($self, $domain) = @_;
	$domain =~ s/\_/\:/;
	for my $dim (@{$self->{'dimension'}}) {
		if ($domain eq $dim->{'val'}) {
			return $dim->{'dim'};
		}
	}
}


sub check_dims() {
	my ($self, $incoming_array) = @_;
	

	my $incoming_total = scalar @{$incoming_array};
	my $self_total = scalar @{$self->{'dimension'}};
	if ($self_total != $incoming_total) {
		return undef;
	}
	
	for my $self_dimension (@{$self->{'dimension'}}) {
		for my $incoming (@{$incoming_array}) {
			$incoming =~ s/\_/\:/;
			if ($incoming eq $self_dimension->{'val'}) {
				$incoming_total--;
				return 1;	
			}
		}
	}

	if ($incoming_total == 0) {
		return 1;
	}
	else {
		return undef;
	}
}


sub is_dim_member() {
	my ($self, $dim_name ) = @_; 
	$dim_name =~ s/\_/:/;
	if (!$self->{'dimension'}) {
		return undef;
	}

	#print "Self: \t" . $self->{'dimension'} . "\n";	
	for my $dim (@{$self->{'dimension'}}) {
		if ($dim_name eq $dim->{'dim'}) {
			return $dim_name;
		}
	}
	return undef;
}

sub get_dim_value() {
	my ($self, $dim_name) = @_;
	$dim_name =~ s/\_/:/;
	
	for my $dim (@{$self->{'dimension'}}) {
		if ($dim_name eq $dim->{'dim'}) {
			return $dim->{'val'};
		}
	}

}

sub has_dim() {
	my ($self) = @_;

	my $dims = $self->{'dimension'};

	if ($dims->[0]) {
		return "dimension";
	}
	else {
		return undef;
	}
}

=head1 XBRL::Context 

XBRL::Context - OO Module for Encapsulating XBRL Contexts 

=head1 SYNOPSIS

  use XBRL::Contexts;

	my $context = XBRL::Context->new($context_xml); 	

	my $id = $context->id(); 

	
=head1 DESCRIPTION

This module is part of the XBRL modules group and is intended for use with XBRL.

=item new   

Object constructor takes a scalar containing the XML representing the context 

=item id 

Get or set the context's ID  

=item scheme 

Get or set the context's scheme  

=item identifier

Get or set the context's identifier  

=item startDate  

Get or set the context's start date   

=item endDate 

Get or set the context's end date  

=item label

Get or set the context's label  

=item dimension

Get or set the context's dimension  

=item duration

Get or set the context's duration  

=item has_dim 

Returns true if the context has any dimensions   

=item get_dim_value 

Takes a the dimension and returns its value  

=item is_dim_member 

Takes a dimension name and returns true if the context 
has the dimension. 

=item check_dims 

Takes an array reference of dimension names and returns 
true if all of the incoming dimensions are present in the context  

=item get_dimension 

Takes a dimension value and returns the value of the dimension. 

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



