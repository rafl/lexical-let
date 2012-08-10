use strict;
use warnings;
use Test::More;

BEGIN { $ENV{PERL_DL_NONLAZY} = 1 }

BEGIN { use_ok('Lexical::Let') }

done_testing;
