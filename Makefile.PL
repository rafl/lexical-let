use strict;
use warnings;
use ExtUtils::MakeMaker;
use IO::File;
use Devel::CallChecker;
use Devel::CallParser;

IO::File->new('callchecker0.h', 'w')->print(
    Devel::CallChecker::callchecker0_h,
);

IO::File->new('callparser.h', 'w')->print(
    Devel::CallParser::callparser0_h,
);

WriteMakefile(
    NAME => 'Lexical::Let',
);
