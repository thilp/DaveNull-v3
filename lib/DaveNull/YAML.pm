package DaveNull::YAML;
# ABSTRACT: Handles everything YAML-related for Dave.

use strict;
use warnings;

# VERSION

use Carp qw/ confess /;
use Params::Util qw/ _INSTANCE _STRING /;
use YAML::XS;

use DaveNull::YAML::Validate 'validate';
use DaveNull::YAML::Grammars;

=head1 SYNOPSIS

    my $rules = DaveNull::YAML->new( 'rules.yml' );

=head1 DESCRIPTION

Parses Dave's YAML rules file (using L<YAML::XS>) and ensures it is conform to
minimal structural expectations.

=cut

my $expected = {
    'grammar-rules?' => { '*' => 'Str!' },
    'mime-structures' => [ { descr => 'Str!', structure => [ 'Any!' ] } ],
    'headers?' => {
        'max-width?' => 'Int',
        '*'          => { 'grammar' => 'Str!', 'required?' => 'Bool!' },
      },
    'body' => {
        'block-separator' => 'Str!',
        'blocks' => {
            '*' => {
                'max-width?'  => 'Int',
                'max-height?' => 'Int',
                'exceptions?' =>
                  [ { name => 'Str!', 'required?' => 'Bool!', '*' => 'Str' } ],
                'branch-on?' => { '*' => 'Str!' },
              },
        },
        'chaining' => 'Str!',
    },
};

=method new( $filename )

Returns a DaveNull::YAML object that is actually just what
C<YAML::XS::LoadFile> returns from C<$filename>. Dies if the validation fails.

=cut

sub new {
    my ($class, $filename) = @_;
    $class = ref $class if ref $class;
    my $self = YAML::XS::LoadFile($filename);
    validate($self, $expected);
    bless $self => $class;
    DaveNull::YAML::Grammars::turn($self);
    $self;
}

sub get {
    my $self  = _INSTANCE( shift, __PACKAGE__ );
    my $spec  = _STRING(shift);
    my $class = ref $self;
    my @keys  = split qr{ / }x, $spec;
    my %seen;
    my ( $node, $parent ) = ( $self, '(root node)' );
    while ( my $k = shift @keys ) {

        if ( exists $node->{$k} ) {
            $node = $node->{$k};
            for ( ref $node ) {
                'HASH'  eq $_ ? $parent = $k :
                'ARRAY' eq $_ ? return map { bless $_ => $class } @$node :
                ''      eq $_ ? return $node :
                confess qq{Unknown datatype for "$k": $_};
            }

            # Update inherited values
            my @scalar_params = grep { !ref( $node->{$k} ) } keys %$node;
            @seen{@scalar_params} = @{$node}{@scalar_params} if @scalar_params;
        }
        else {
            exists $seen{$k}
              ? return $seen{$k} : confess qq{No key "$k" under "$parent"!};
        }
    }
    confess qq{"$parent" is a block, not a value: won't return it!};
}

1;
