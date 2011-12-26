package XBRL::Context;

use strict;
use warnings;
use Date::Manip::Date;
use Carp;
use Data::Dumper;


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

	$self->{'id'} = $in_xml->getAttribute( 'id' );
	my @nodes = $in_xml->getElementsByTagName('xbrli:identifier'); 
	#print $nodes[0]->toString() . "\n";	
	$self->{'scheme'} = $nodes[0]->getAttribute( 'scheme' );
	$self->{'identifier'} = $nodes[0]->textContent();
	my @starts = $in_xml->getElementsByTagName('xbrli:startDate'); 

	my $start_date = Date::Manip::Date->new();
	$start_date->config("language", "English", "tz", "America/New_York");


	if ($starts[0]) {
	#	$self->{'startDate'} = $starts[0]->textContent(); 
		$start_date->parse($starts[0]->textContent()); 
		$self->{'startDate'} = $start_date; 
	}	
	
	my @ends = $in_xml->getElementsByTagName('xbrli:endDate');
	my $end_date = $start_date->new_date();

	if ($ends[0]) {
		#$self->{'endDate'} = $ends[0]->textContent();
		$end_date->parse($ends[0]->textContent());	
		$self->{'endDate'} = $end_date;  
		
	}

	my @times = $in_xml->getElementsByTagName('xbrli:instant');
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
		my $delta_month = $delta->printf("%Mv");
		my $delta_weeks = $delta->printf("%wv");
		$delta_month = $delta_month + $delta_weeks / 4;
		$self->{'duration'} = $delta_month;

		my $end_of_time = $self->{'endDate'}->printf("%B %d, %Y");  
			
		$self->{'label'} = "$delta_month months ending $end_of_time";	
	
	}

	#add the dimension 
	#FIXME  Need to deal properly with the whole dimension thing.  	
	my @dim_nodes = $in_xml->getElementsByTagName('xbrldi:explicitMember'); 
	my @dim_array = ();	
	for my $dim (@dim_nodes) {	
		my $dim_name = $dim->getAttribute('dimension');  
		my $val = $dim->textContent();	
		push(@dim_array, { dim => $dim_name, val => $val }); 	
	}
		$self->{'dimension'} = \@dim_array; 
	

}

sub is_dim_member() {
	my ($self, $dim_name ) = @_; 

	if (!$self->{'dimension'}) {
		return 0;
	}

	#print "Self: \t" . $self->{'dimension'} . "\n";	
	for my $dim (@{$self->{'dimension'}}) {
		if ($dim_name = $dim->{'dim'}) {
			return 1;
		}
	}
}


1;



