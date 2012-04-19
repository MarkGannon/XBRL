# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl XBRL.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Test::More tests => 29;
BEGIN { use_ok('XBRL') };
require_ok( 'XBRL' );


#########################

#Get the test aol xbrl file 
use LWP::UserAgent;
my $ua = LWP::UserAgent->new();
$ua->agent("Perl XBRL Library");

my $base_url		= 'http://www.sec.gov/Archives/edgar/data/1468516/000119312511215260/';
my $main_doc   	= 'aol-20110630.xml';
my $schema_doc 	= 'aol-20110630.xsd';
my $pres_doc   	= 'aol-20110630_pre.xml';
my $cal_doc    	= 'aol-20110630_cal.xml';
my $def_doc    	= 'aol-20110630_def.xml'; 
my $lab_doc    	= 'aol-20110630_lab.xml';

sub fetch_doc() {
	my ($file_name) = @_;			

	my $response = $ua->get($base_url . $file_name);
	if ($response->is_success) {
		my $fh;	
		open($fh, ">$file_name") or croak "can't open $file_name because: $! \n";
		print $fh $response->content;	
		close $fh;	
	}
}


if (! -e $main_doc) {
	&fetch_doc($main_doc);
}
if (! -e $schema_doc) {
	&fetch_doc($schema_doc);
}
if (! -e $pres_doc ) {
	&fetch_doc($pres_doc);
}
if (! -e $cal_doc ) {
	&fetch_doc($cal_doc);
}
if (! -e $def_doc ) {
	&fetch_doc($def_doc);
}
if (! -e $lab_doc) {
	&fetch_doc($lab_doc);
}



# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


my $xbrl_file = 'aol-20110630.xml';  


my $doc = XBRL->new({file => $xbrl_file}); 
#my $doc = XBRL->new({file => $xbrl_file, schema_dir=>"/var/cache/xbrl"});

ok($doc);

my $context;

my $test_id = "FROM_Apr01_2011_TO_Jun30_2011";

ok($context = $doc->get_context($test_id));

my $context_id = $context->identifier();

ok($context_id eq '0001468516', "Context ID"); 

my $scheme = $context->scheme();

ok($scheme eq 'http://www.sec.gov/CIK', "Context Scheme"); 

my $startDate = $context->startDate();

my $start_string = $startDate->printf("%Y-%m-%d");

ok($start_string eq '2011-04-01', "Context Start Date"); 

my $endDate = $context->endDate();

my $end_string = $endDate->printf("%Y-%m-%d");

ok($end_string eq '2011-06-30', "Context End Date"); 

my $period_id = 'AS_OF_Jun30_2011';

my $instant_context = $doc->get_context($period_id);

my $instant = $instant_context->endDate();

my $instant_string = $instant->printf("%Y-%m-%d");

ok($instant_string eq '2011-06-30', "Instant Date"); 

my $unit_id = 'USD';

my $unit = $doc->get_unit($unit_id);

my $retrieved_id = $unit->id();

ok($retrieved_id eq 'USD', "Unit Id");

my $meas = $unit->measure();

ok ($meas eq 'iso4217:USD', "Unit Measure");

my $dual_id = 'USDperShare'; 

my $dual_unit = $doc->get_unit($dual_id);

my $nominator = $dual_unit->numerator();

ok ($nominator eq 'iso4217:USD', "Unit Nominator");

my $dominator = $dual_unit->denominator();

ok ($dominator eq 'xbrli:shares', "Unit Denominator");

my $seek_name = 'us-gaap:RestrictedCashAndCashEquivalentsNoncurrent';
my $seek_context = 'AS_OF_Jun30_2011';
my $item = $doc->get_item($seek_name, $seek_context);

my $decimal = $item->decimal();

ok($decimal eq '-5', "Item Decimal");

my $item_unit = $item->unit(); 

ok($item_unit eq 'USD', "Item Unit");

my $item_id = $item->id();

ok($item_id eq 'ID_1387_USD_Millions', "Item ID");

my $item_context = $item->context();

ok($item_context eq 'AS_OF_Jun30_2011', "Item Context");

my $item_name = $item->name();

ok($item_name eq 'us-gaap:RestrictedCashAndCashEquivalentsNoncurrent', "Item Name");

my $item_value = $item->value();

ok($item_value eq '13000000', "Item Value");

#my $item_label = $item->label();

#ok($item_label eq 'Restricted Cash And Cash Equivalents Noncurrent', "Item Label"); 

my $all_name = 'us-gaap:EffectiveIncomeTaxRateContinuingOperations';

my $all_contexts = $doc->get_item_all_contexts($all_name);   

my $count = scalar @$all_contexts;

ok($count == 4, "Item All Contexts"); 

my $all_items = $doc->get_all_items(); 

my $all_items_count = scalar @$all_items;

ok($all_items_count == 411, "All Items Count");

my $contexts = $doc->get_all_contexts();

my $total_contexts = scalar keys %{$contexts};

ok($total_contexts == 91, "All Contexts Count");


#Test to see if the context diminsionality is being parsed correctly
my $dim_id = 'AS_OF_Dec31_2009_us-gaap_StatementEquityComponentsAxis_AdditionalPaidInCapitalMember';

my $dim_context = $doc->get_context($dim_id); 


ok($dim_context->id()  eq $dim_id, "Context Diminension"); 

#my $dim = $dim_context->dimension();

#ok($dim eq 'us-gaap:AdditionalPaidInCapitalMember', "Context Dimension"); 


#Test the element stuff in Taxonomy

my $taxonomy = $doc->get_taxonomy();

my $element = $taxonomy->get_elementbyid('aol_GoodwillByTypeAxis');  

my $element_name = $element->name();

ok($element_name eq 'GoodwillByTypeAxis', "Element Name"); 

my $element_type = $element->type();

ok($element_type eq 'xbrli:stringItemType', "Element Type");

my $element_subGroup = $element->subGroup();

ok($element_subGroup eq 'xbrldt:dimensionItem', "Element Substition Group"); 

my $element_abstract = $element->abstract();

ok($element_abstract eq 'true', "Element Abstract");

my $element_nillable = $element->nillable();

ok($element_nillable eq 'true', "Element Nillable");

my $element_period = $element->periodType();

ok($element_period eq 'duration', "Element Period Type");



