# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl XBRL.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Carp;

use Test::More tests => 4;
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

ok($doc);

my $context;

my $test_id = "Third";

ok($context = $doc->get_context($test_id));



