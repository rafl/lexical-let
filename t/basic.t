use strict;
use warnings;
use Test::More;

use let;

sub let { }

my $foo = let (
    $foo = 'bar';
    @bar = ('baz', 'moo');
) {
    'foo'
};

done_testing;
