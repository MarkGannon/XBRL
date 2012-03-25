use 5.010;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'XBRL',
    VERSION_FROM      => 'lib/XBRL.pm', # finds $VERSION
    PREREQ_PM         => { 'Carp' => 1.25,
			'LWP::UserAgent' => 6.04,
			'Date::Manip' => 6.30,	
			'Class::Accessor' => 0.34,	
			'File::Spec' => 3.33,
			'File::Temp' => 0.22,	
			'Exporter' => 5.66,	
			'HTML::Table' => 2.08,	
			'XML::LibXML' => 1.90  }, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/XBRL.pm', # retrieve abstract from module
       AUTHOR         => 'Mark Gannon <mark@truenorth.nu>') : ()),
);
