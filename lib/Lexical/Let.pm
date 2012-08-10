use strict;
use warnings;

package Lexical::Let;
# ABSTRACT: Let block scoping keyword

use Carp 'croak';
use XSLoader;
use Devel::CallChecker;
use Devel::CallParser;
use namespace::clean;

use Sub::Exporter -setup => {
    exports => ['let'],
    groups  => { default => ['let'] },
};

sub let { croak 'let called as a function' }

XSLoader::load(__PACKAGE__);

1;
