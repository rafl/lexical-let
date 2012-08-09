use strict;
use warnings;
use Test::More;

use let;

my $foo = let (
    $foo = 'bar';
    @bar = ('baz', $foo);
    %baz = (1, 2, @bar);
) {
    [$foo, \@bar, \%baz];
};

diag explain $foo;

done_testing;
