use strict;
use warnings;
use Test::More;

BEGIN { $ENV{PERL_DL_NONLAZY} = 1 }

BEGIN { use_ok('let') }

done_testing;
