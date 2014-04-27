package DaveNull::Email::Multipart;
# ABSTRACT: Representation of a composite email part.

## no critic (RequireUseStrict)
# VERSION

use Moo;
with 'DaveNull::Email';

use MooX::Types::MooseLike::Base qw/ ArrayRef ConsumerOf /;

use namespace::clean;

=head1 DESCRIPTION

See DaveNull::Email.

=cut

sub BUILDARGS {
    my $class = shift;
    return @_ % 2 ? { emailmime => _mk_em(shift), @_ } : {@_};
}

=attr subparts

Arrayref containing this email's subparts as other DaveNull::Email objects.

=cut

has subparts => (
    is      => 'ro',
    isa     => ArrayRef[ ConsumerOf['DaveNull::Email'] ],
    lazy    => 1,
    builder => 1,
);

sub _build_subparts {
    [ map { DaveNull::Email->instantiate($_) } $_[0]->emailmime->subparts ]
}

1;
