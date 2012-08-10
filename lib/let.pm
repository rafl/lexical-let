use strict;
use warnings;

package let;

use Carp 'croak';
use XSLoader;
use Devel::CallChecker;
use Devel::CallParser;
use namespace::clean;

use Sub::Exporter -setup => {
    exports => ['let'],
    groups  => { default => ['let'] },
};

sub let { croak 'fail' }

XSLoader::load(__PACKAGE__);

1;
