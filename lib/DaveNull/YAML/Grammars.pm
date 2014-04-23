package DaveNull::YAML::Grammars;
# ABSTRACT: Turn Dave's rules into truly recursive regexes.

use strict;
use warnings;

# VERSION

use Carp qw/ confess /;
use Params::Util qw/ _INSTANCE /;

=begin wikidoc

= SYNOPSIS

    DaveNull::YAML::Grammars::turn( $daveyaml );

= DESCRIPTION

This package provides a {turn} function that walks a DaveNull::YAML object and
transforms its "grammars" into real Perl regexes.

== Dave's grammars

Dave's so-called "grammars" are simply strings that use the same syntax than
Perl 5 regexes, except for one thing they stole from Perl 6: *subrules*. For
instance, the following is a Dave grammar matching opening {<a>} HTML tags
with a ~href~ attribute:

    ^ < a \h href = <quoted-string> > $

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
    my $name_pattern = qr/ [a-z] [a-z_-]* (?<=[a-z_]) /xi;
    ( qr/<$name_pattern>/, qr/<($name_pattern)>/ );
};

sub turn {
    my $doc = _INSTANCE( shift, $DOCTYPE )
      or confess "Expecting a $DOCTYPE object";
    my %rules = %{ _harvest_primary_rules($doc) };
    _transform_all_grammars($doc, \%rules);
    $doc
}

sub _isa_hash { ref $_[0] eq 'HASH' || ref $_[0] eq $DOCTYPE }

# Changes a rule name into a subpattern name.
sub _rename {
    my ($subrule) = @_;
    $subrule =~ y/-/0/; # fortunately i forgot to allow 0-9 in subrule names :D
    return $subrule;
}

# Replaces all "<subrule>" calls by real named subpattern recursions in
# $grammar.
sub _turn {
    my ($grammar) = @_;
    $grammar =~ s/ $SUBRULE_REGEX_capture / '(?&' . _rename($1) . ')' /xeg;
    $grammar;
}

# Builds a $rules out of the $PRIMARY_RULES_BLKNAME bloc of $doc.
# $rules->{re}: Pseudo-regexes (strings ready for qr//) for each rule.
# $rules->{deps}: Lists of dependencies for each rule.
sub _harvest_primary_rules {
    my $doc = shift;

    exists $doc->{$PRIMARY_RULES_BLKNAME} or return;

    my %primary = %{ $doc->{$PRIMARY_RULES_BLKNAME} };
    delete $doc->{$PRIMARY_RULES_BLKNAME};

    # Build the dependency tree (some rules may recurse to others)
    my %dependencies =
      map { $_ => [ _direct_deps( $primary{$_} ) ] } keys %primary;
    # TODO: add unknown dependency detection
    _resolve_all_deps(\%dependencies);

    my %regexes = map { $_ => _turn($primary{$_}) } keys %primary;

    return { deps => \%dependencies, re => \%regexes };
}

# Returns a list of all subrules needed in $grammar (not only the ones used
# directly in $grammar, but the ones these use too, etc.).
sub _all_deps {
    my ( $grammar, $rules ) = @_;
    map { ( $_, @{ $rules->{deps}{$_} } ) } _direct_deps($grammar);
}

# Returns a list of subrules namely used in $grammar.
sub _direct_deps {
    my ($grammar) = @_;
    if (wantarray) { $grammar =~ /$SUBRULE_REGEX_capture/g }
    else {
        my @deps = $grammar =~ /$SUBRULE_REGEX_capture/g;
        scalar @deps;
    }
}

# Simplifies $dependencies so that not only direct dependencies of a "foo"
# rule, but also all its indirect dependencies, are listed in
# $dependencies->{foo}.
sub _resolve_all_deps {
    my $dependencies = shift;
    for my $r (keys %$dependencies) {
        $dependencies->{$r} = [ _resolve_dep($r, $dependencies) ];
    }
    return;
}

# Returns the list of rules on which $rule depends (according to
# $dependencies->{$rule}.
# This function is recursive, so it is important that $dependencies be the
# whole dependency hash.
# This function support mutual dependencies and self-dependencies.
# Dies if, for any dependency "foo", $dependencies->{foo} does not exist.
sub _resolve_dep {
    my ( $rule, $dependencies, %seen ) = @_;

    exists $dependencies->{$rule}
      or confess qq{Can't resolve dependencies for unknown rule "$rule"};

    $seen{$rule} = 1;
    map { $seen{$_} ? () : ( $_, _resolve_dep( $_, $dependencies, %seen ) ) }
      @{ $dependencies->{$rule} || [] };
}

# Transform $grammar into a Perl 5 regex, resolving subrule calls using
# the $rules hash that comes from _harvest_primary_rules.
sub _transform_grammar {
    my ( $grammar, $rules ) = @_;

    # Ensure all subrules in $grammar exist
    exists $rules->{re}{$_} or confess qq{Unknown rule "$_" in "$grammar"}
      for _direct_deps($grammar);

    my $prelude = _prelude($grammar, $rules);
    $grammar = _turn($grammar);
    qr/$prelude $grammar/x;
}

# Builds a regex-ready string that defines all named subpatterns used in
# $grammar (these subpatterns must exist in $rules or this function will die).
sub _prelude {
    my ( $grammar, $rules ) = @_;

    my %definitions =
      map { '(?<' . _rename($_) . '>' . $rules->{re}{$_} . ')' => 1 }
      _all_deps( $grammar, $rules );

    %definitions ? '(?(DEFINE)' . join( '', keys %definitions ) . ')' : '';
}

# Recursively changes all $GRAMMAR_BLKNAME values under $tree using
# _transform_grammar.
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
