use 5.012000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'RSBX::Development::Tracer',
    VERSION_FROM      => 'lib/RSBX/Development/Tracer.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/RSBX/Development/Tracer.pm', # retrieve abstract from module
    AUTHOR            => 'Raymond S Brand <rsbx@acm.org>',
);
