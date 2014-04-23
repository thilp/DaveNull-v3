package DaveNull::YAML::Grammars;
# ABSTRACT: Turn Dave's rules into truly recursive regexes.

use strict;
use warnings;

# VERSION

use Carp qw/ confess /;
use Params::Util qw/ _INSTANCE /;

use Data::Dump::Color;

=begin wikidoc

= SYNOPSIS

    DaveNull::YAML::Grammars::turn( $daveyaml );

= DESCRIPTION

This package provides a {turn} function that walks a DaveNull::YAML object and
transforms its "grammars" into real Perl regexes.

== Dave's grammars

Dave's so-called "grammars" are simply strings that use the same syntax than
Perl 5 regexes, except for one thing they stole from Perl 6: *subrules*. For
instance, the following is a Dave grammar matching opening {<a>} HTML tags:

    ^ < a href=<quoted-string> > $

That's a standard Perl 5 regex, except for the {<quoted-string>} part, which
would be a subrule call in Perl 6 grammars, where it would refer to a
"quoted-string" rule defined somewhere else. This allows to easily build
parsers. In Dave (where, to simplify things, {<quoted-string>} is called "a
subrule" too), this behavior must be emulated through the use of good old Perl
5 ~named subpattern recursion~.

== Transformation

When given {$doc} (a DaveNull::YAML document), {turn} performs the following
steps on it:

0 Harvest primary rules defined in {$doc}'s root-level {grammar-rules} block,
if such a block exists, then delete this block. Order these primary rules
according to their dependencies (so *DON'T* create *mutual dependencies* in
primary rules!) and turn them into regexes.
0 Replace the value of each {grammar} key anywhere else in {$doc} by a regex
(that may depend on regexes produced from primary rules).

Turning a "string rule" into a real Perl 5 regex is done as follow:

0 Replace each "<foo>" substring (here "foo" is metasyntactic) with "(?&foo)".
0 Including subrule definitions at the beginning, extrapolate the string into
a mere regex.

== Exports

This package exports nothing: its only "public" function is {turn}, which
should not need to be used more than once.

= FUNCTIONS

== turn( $daveyaml )

If {$daveyaml} is a DaveNull::YAML object, transforms it according to what is
described in [Transformation]. Dies if any error occurs.

=end wikidoc

=cut

my $DOCTYPE               = 'DaveNull::YAML';
my $PRIMARY_RULES_BLKNAME = 'grammar-rules';
my $GRAMMAR_BLKNAME       = 'grammar';
my ( $SUBRULE_REGEX, $SUBRULE_REGEX_capture ) = do {
    my $name_pattern = qr/ [a-z] [a-z_-]* (?<=[a-z]) /xi;
    ( qr/<$name_pattern>/, qr/<($name_pattern)>/ );
};

sub turn {
    my $doc = _INSTANCE( shift, $DOCTYPE )
      or confess "Expecting a $DOCTYPE object";
    my %rules = _harvest_primary_rules($doc);
    dd \%rules;
    _transform_all_grammars($doc, \%rules);
    $doc
}

sub _isa_hash { ref $_[0] eq 'HASH' || ref $_[0] eq $DOCTYPE }

sub _rename {
    my ($subrule) = @_;
    $subrule =~ y/-/0/; # fortunately i forgot to allow 0-9 in subrule names :D
    return $subrule;
}

sub _harvest_primary_rules {
    my $doc = shift;

    exists $doc->{$PRIMARY_RULES_BLKNAME} or return;

    my %primary = %{ $doc->{$PRIMARY_RULES_BLKNAME} };
    delete $doc->{$PRIMARY_RULES_BLKNAME};
    my %rules;

    # Build the dependency tree so that we can transform them into regexes
    # in the right order (some may recurse to others).
    #my %dependencies;
    #for my $r (%primary) {
    #    my @subrules = $primary{$r} =~ /$SUBRULE_REGEX/g;
    #    $dependencies{$r} = \@subrules;
    #}

    # TODO: add unknown dependency detection
    # TODO: add self-dependency detection
    # TODO: add mutual dependency detection

    for my $r ( keys %primary ) {
        ( $rules{$r} = $primary{$r} ) =~
          s/ $SUBRULE_REGEX_capture / '(?&' . _rename($1) . ')' /xeg;
    }

    return %rules;
}

sub _prelude {
    my $rules = shift;
    '(?(DEFINE)' . join(
        '' => map { '(?<' . _rename($_) . '>' . $rules->{$_} . ')' }
          keys %$rules
      ) . ')';
}

sub _transform_grammar {
    my ( $grammar, $rules ) = @_;
    my @deps = $grammar =~ /$SUBRULE_REGEX_capture/g;
    if (@deps) {
        exists $rules->{$_}
          or confess qq{Using undefined subrule <$_> in "$grammar"}
          for @deps;
        $grammar =~ s/ $SUBRULE_REGEX_capture / '(?&' . _rename($1) . ')' /xeg;
        my $prelude = _prelude($rules);
        qr/ $prelude $grammar /x;
    }
    else { qr/ $grammar /x }
}

sub _transform_all_grammars {
    my ( $tree, $rules ) = @_;

    if ( _isa_hash($tree) ) {

        exists $tree->{$GRAMMAR_BLKNAME}
          and $tree->{$GRAMMAR_BLKNAME} =
          _transform_grammar( $tree->{$GRAMMAR_BLKNAME}, $rules );

        for my $k ( keys %$tree ) {
            if ( ref $tree->{$k} eq 'HASH' ) {
                _transform_all_grammars( $tree->{$k}, $rules );
            }
            elsif ( ref $tree->{$k} eq 'ARRAY' ) {
                _transform_all_grammars( $_, $rules ) for @{ $tree->{$k} };
            }
        }

    }
}

1;
