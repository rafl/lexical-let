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

XSLoader::load(
    __PACKAGE__,
    $Lexical::Let::{VERSION} ? ${ $Lexical::Let::{VERSION} } : (),
);

=head1 SYNOPSIS

    use Lexical::Let;

    my $value = let ($x = 23) { $x * 2 };

=head1 DESCRIPTION

This syntax extension introduces a C<let> keyword similar to those found in many
Lisp variants. It is basically a short form of declaring lexicals and having a
block in which those lexicals will be available.

=head1 SYNTAX

=for Pod::Coverage let

    let (<lhs> = <expr>; <lhs> = <expr>; ...) ... { <body> }

The syntax is triggered with the C<let> keyword, followed by a sequence
(can be none at all, or many) of variable declarations, followed by a
block in which the declared variables will be available.

    let ($x = 23) { $x }
    let (@y = (3..7)) { @y }
    let (%z = (x => 42)) { $z{x} }
    let (($x, $y) = (42, 23)) { $x + $y }
    let ($x = 42; $y = 23) { $x + $y }
    let ($x = 42) ($y = 23) { $x + $y }

=head2 Expression Details

The whole C<let> keyword is an expression, not a statement. This means you must
terminate the statement yourself. It also means the C<let> expressions can be
used inside any other expression:

    my $x = let ($y = 23) { $y } + let ($z = 42) { $z };

The context will also be properly propagated to the block.

=head2 Sequential Access

The lexicals that are declared can be sequentially accessed. This means that
every variable can access those before it:

    let ($x = 23) ($y = $x * 2) { $y }
    let ($x = 23;  $y = $x * 2) { $y }

=head2 Transformation

Internally, the C<let> expression will be turned into a C<do> expression. This
is done at an optree level and should result in rather fast code.

    let ($x = 23) { say $x }

will be transformed into (more or less):

    do { my $x = 23; say $x }

=cut

1;
