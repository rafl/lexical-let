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

The syntax is triggered with the C<let> keyword, followed by a sequence (can be
none at all, or many) of variable declarations, followed by a block in which the
declared variables will be available.

    let ($x = 23) { $x }
    let (@y = (3..7)) { @y }
    let (%z = (x => 42)) { $z{x} }
    let (($x, $y) = (42, 23)) { $x + $y }
    let ($x = 42; $y = 23) { $x + $y }
    let ($x = 42) ($y = 23) { $x + $y }

=head2 Expression Details

The C<let> keyword is an expression, not a statement. This means the C<let>
expressions can be used inside any other expression:

    my $x = let ($y = 23) { $y } + let ($z = 42) { $z };
    push @x, let (...) { ... };

The context (scalar, list, etc) in which let is used is propagated to the let
block. The context of the left hand side of variable assignments within let
declarations is propogated into the expression on the right hand side.

    my $x = let (...) { @foo }; # @foo is evaluated in scalar context
    my @y = let (...) { @foo }; # @foo is evaluated in list context

=head2 Sequential Access

When multiple variables are declared in a single let statement, subsequent
variables have access to any variable declared before it. For example, a
variable x declared first in a let statement is available for use by a variable
y declared after it. A variable z declared after y has access to both y and x. x
and y, however, cannot use z, and x cannot use y.

    let ($x = 23) ($y = $x * 2) { $y }
    let ($x = 23;  $y = $x * 2) { $y }

=head2 Implementation Details

Internally, this module turns a C<let> expression into a C<do>
expression. Because this transformation is done at an optree level it results in
rather fast code.

    let ($x = 23) { say $x }

turns into (more or less):

    do { my $x = 23; say $x }

=cut

1;
