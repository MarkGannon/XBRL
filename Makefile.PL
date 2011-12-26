use 5.012004;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'XBRL',
    VERSION_FROM      => 'lib/XBRL.pm', # finds $VERSION
    PREREQ_PM         => { 'Carp' => 0.01,
											'XML::LibXML::XPathContext' => 0.01  }, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/XBRL.pm', # retrieve abstract from module
       AUTHOR         => 'Mark Gannon <mark@truenorth.nu>') : ()),
);
