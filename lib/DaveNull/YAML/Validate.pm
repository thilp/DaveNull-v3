package DaveNull::YAML::Validate;
# ABSTRACT: Light, Perl-oriented YAML document validator for rules file.

use strict;
use warnings;

# VERSION

use Carp ();
use Data::Dump 'dump';

BEGIN {
    eval { require Data::Dump::Color }
      and Data::Dump::Color->import('dump');
}

use parent 'Exporter';
our @EXPORT_OK = qw/ validate /;

=begin wikidoc

= SYNOPSIS

    use DaveNull::YAML::Validate 'validate';

    eval { validate( $document, $specification ) };
    print $@ and exit if $@;

= DESCRIPTION

This package provides a {validate} method that checks if a given data
structure conforms to a specification.

== Specification format

The specification format makes use of Perl data structures to represent the
ones used in documents to validate. Thus, if you want your document to be an
arrayref of scalars, your specification will be an arrayref of scalars too.
The specification differs from a standard document (and therefore can
represent a whole class of such standard documents) by its use of wildcard
characters:

* {Any} represents a anything (reference or not);
* {Str} represents a string (i.e. a non-reference);
* {Int} represents an integer (i.e. a numeric {Str}) or {undef};
* {Bool} represents "0" or "1" or {undef};
* {!} used after {Any}, {Str}, {Int} or {Bool} means that the value can't be
undefined;
* {*} used as a hash key means that all values of this hash must conform to
the specified value corresponding to the {*} key, regardless of their own key;
* {?} used as last character of a hash key means that this key is optional
(but the corresponding value must conform to what is specified if the key
exists).

== Exports

This package exports {validate} on-demand, as demonstrated in [SYNOPSIS].

= FUNCTIONS

== validate( $document, $spec )

Returns {1} if {$document} is conform to {$spec} according to the
[Specification format]. Dies otherwise.

=end wikidoc

=cut

my %translate = (
    Bool => '0 or 1',
    Int  => 'positive integer',
    Str  => 'string',
    Any  => 'anything',
);

sub _explain_spec {
    my ($spec) = @_;
    if ( ref $spec ) { dump( $_[0] ) }
    else {
        ( my $s = $spec ) =~ s/!$//;
        my $d = $s eq $spec ? '' : ' defined';
        qq{"$spec" (a$d $translate{$s})};
    }
}

sub _fail (@) { chomp(my @a = @_); die join('' => @a) . "\n" }

sub _rethrow ($$$) {
    my $depth = int( 4 / ( 1 + @{ [ $_[0] =~ /when validating/g ] } ) ) || 1;
    _fail(
        $_[0],
        "\n\n---> when validating ",
        dump( _limit_depth( $_[1], $depth ) ),
        " against ", _explain_spec( $_[2] )
    );
}

sub _limit_depth {
    my ($struct, $limit) = @_;
    return '...' unless $limit || !ref($struct);
    for (ref $struct) {
        if ($_ eq 'ARRAY') {
            return [ map { _limit_depth($_, $limit - 1) } @$struct ];
        }
        elsif ( $_ eq 'HASH' ) {
            my %shortened;
            @shortened{ keys %$struct } =
              map { _limit_depth( $_, $limit - 1 ) } values %$struct;
            return \%shortened;
        }
        else { return $struct }
    }
}

sub validate {
    eval { _validate(@_) };
    if ($@) {
        chomp $@;
        Carp::croak( "YAML validation failed: $@\n\nFrom "
              . __PACKAGE__ . "::validate() called" );
    }
}

sub _validate {
    my ($thing, $spec) = @_;
    ref($thing) eq ref($spec)
      or _fail(
        "type mismatch: ", dump($thing),
        " should match ",  _explain_spec($spec)
      );
    for (ref $spec) {
        '' eq $_ || 'Regexp' eq $_ ? _validate_scalar($thing, $spec) :
        'ARRAY' eq $_              ?  _validate_array($thing, $spec) :
        'HASH'  eq $_              ?   _validate_hash($thing, $spec) :
        _fail qq{can't validate "$thing" of unsupported type "$_"};
    }
    return 1;
}

sub _validate_hash {
    my ( $hash, $spec ) = @_;
    my $asterisk = 0;
    my %not_in_asterisk;
    for my $k ( keys %$spec ) {
        if ( $k eq '*' ) { $asterisk = 1; next }

        ( my $a = $k ) =~ s/\?$//;
        if ( exists $hash->{$a} ) {
            eval { _validate( $hash->{$a}, $spec->{$k} ); 1 }
              or _rethrow($@, $hash->{$a}, $spec->{$k});
            $not_in_asterisk{$a} = 1;
        }
        elsif ( $a ne $k ) { next }    # optional key not present
        else               { _fail qq{required key "$a" not found} }
    }
    if ($asterisk) {
        _validate( $hash->{$_}, $spec->{'*'} )
          for grep { !$not_in_asterisk{$_} } keys %$hash;
    }
    return 1;
}

sub _validate_scalar {
    my ( $value, $spec ) = @_;
    return $value =~ $spec if ref $spec eq 'Regexp';

    !ref($spec) or _fail 'specification error: invalid use of ', ref($spec);
    defined($spec) or _fail 'specification error: invalid use of undef';
    ( my $s = $spec ) =~ s/!$//;
    exists $translate{$s}
      or _fail qq{specification error: use of unknown wildcard "$s"};

    if ( $spec ne $s ) {
        defined $value
          or _fail "got undef but expected ", _explain_spec($spec);
    }

    if ( $s eq 'Any' ) { return 1 }
    elsif ( !ref($value) ) {
        if ( $s eq 'Str' ) { return 1 }
        elsif ( $value =~ /^\d+$/ ) {
            if ( $s eq 'Int' ) { return 1 }
            elsif ( $value =~ /^[01]$/ ) {
                if ( $s eq 'Bool' ) { return 1 }
            }
        }
    }
    _fail qq{"$value" doesn't match constraints for "$spec"};
}

sub _validate_array {
    my ($array, $spec) = @_;
    if (@$spec) {
        my $subtype = ref $spec->[0];
        if ( $subtype eq '' ) {
            _validate_scalar($_, $spec->[0]) for @$array;
        }
        elsif ( $subtype eq 'HASH' ) {
            _validate_hash($_, $spec->[0]) for @$array;
        }
        elsif ( $subtype eq 'ARRAY' ) {
            _validate_array($_, $spec->[0]) for @$array;
        }
        else {
            _fail qq{can't validate unsupported type "$subtype"};
        }
    }
    return 1;
}

1;
