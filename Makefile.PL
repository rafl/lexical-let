use strict;
use warnings;
use ExtUtils::MakeMaker;

use lib 'inc';
use MMHelper;

eval MMHelper::header_generator() or die $@;

WriteMakefile(
    NAME     => 'Lexical::Let',
    NORECURS => 1,
    CCFLAGS  => MMHelper::ccflags_static('dev'),
    MMHelper::mm_args(),
);
