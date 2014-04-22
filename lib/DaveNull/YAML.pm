package DaveNull::YAML;
# ABSTRACT: Handles everything YAML-related for Dave.

use strict;
use warnings;

# VERSION

use YAML::XS;
use DaveNull::YAML::Validate 'validate';

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
    return bless $self => $class;
}

1;
