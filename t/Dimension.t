# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl XBRL.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Carp;

use Test::More tests => 10;
BEGIN { use_ok('XBRL') };
require_ok( 'XBRL' );


#########################

my $main_doc   	= 't/fubar-02.xml';
my $schema_doc 	= 't/fubar-02.xsd';
my $pres_doc   	= 't/fubar-02_pre.xml';
my $def_doc    	= 't/fubar-02_def.xml'; 
my $lab_doc    	= 't/fubar-02_lab.xml';




# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


my $doc = XBRL->new({file => $main_doc}); 

ok($doc, "Document Created");

my $dim_uri = 'http://www.fubar.com/role/DisclosureDescriptionOfBusinessBasisOfPresentationAndSummaryOfSignificantAccountingPoliciesDetails';

my $dim = XBRL::Dimension->new($doc, $dim_uri);

ok($dim, "Dimension Created");

my $xml_table = $dim->get_xml_table();

ok($xml_table, "Create XML Table");

my $row_array_ref = $xml_table->getRows();

my $row_num = scalar @{$row_array_ref};

ok($row_num eq '7', "Number of Rows");

my $expected_label = 'Entity Wide Disclosure On Geographic Areas Revenue From External Customers Attributed To Entitys Country Of Domicile';

my $label = $xml_table->label('2');

ok($label eq $expected_label, "XML Table Row Label");

my $expected_id = 'us-gaap_EntityWideDisclosureOnGeographicAreasRevenueFromExternalCustomersAttributedToEntitysCountryOfDomicile';

my $row_id = $xml_table->get_row_id('2');

ok($row_id eq $expected_id, "XML Table Row ID");

my $expected_contents = '24400000'; 

my $cell_contents = $xml_table->getCell('2', '2');

ok($cell_contents eq $expected_contents, "Get Cell Contents");

my $new_contents = '25';

$xml_table->setCell('2', '2', $new_contents);

$cell_contents = $xml_table->getCell('2', '2'); 

ok($cell_contents eq $new_contents, "XML Table Set Cell"); 




