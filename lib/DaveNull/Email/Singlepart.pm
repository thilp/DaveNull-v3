package DaveNull::Email::Singlepart;
# ABSTRACT: Representation of a non-composite email part.

## no critic (RequireUseStrict)
# VERSION

use Moo;
with 'DaveNull::Email';

use Params::Util qw/ _INSTANCE /;
use MooX::Types::MooseLike::Base qw/ AnyOf Str Undef Int ArrayRef /;
use Email::MIME;
use Text::Tabs;

use Data::Dump::Color;

use namespace::clean;

=head1 DESCRIPTION

See DaveNull::Email.

=cut

sub BUILDARGS {
    my $class = shift;
    return @_ % 2 ? { emailmime => _mk_em(shift), @_ } : {@_};
}

=method body

The email body (as returned by C<Email::MIME::body_str> and filtered by
C<Text::Tabs::expand>) or C<undef> (if C<Email::MIME::body_str> throws an
exception).

=cut

has body => (
    is      => 'ro',
    isa     => AnyOf[Undef, Str],
    lazy    => 1,
    builder => 1,
);

sub _build_body {
    my $body = eval { $_[0]->emailmime->body_str };
    $body = expand($body) if defined $body;
    $body
}

=method nextline

Iterator-like behavior over C<body>'s content. Each call to C<nextline>
returns the current line (starting from the first one), moves an internal
pointer to the next line and increments C<lineno>. Returns undef when there is
no more lines to fetch.

=cut

has _splitted_body => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    lazy    => 1,
    builder => '_build_splitted_body',
);

sub _build_splitted_body { [ split /\n/ => $_[0]->body ] }

sub nextline {
    my $self   = _INSTANCE( shift, __PACKAGE__ );
    my $lineno = $self->lineno;
    my $line   = $self->_splitted_body->[ $lineno ];
    return unless defined $line;
    $self->_set_lineno( $lineno + 1 );
    return $line;
}

=attr lineno

The number of the line returned by the last call to C<nextline>, starting from
0 (no line).
This number is incremented by each call to C<nextline>.

=cut

has lineno => (
    is      => 'rwp',
    isa     => Int,
    default => 0,
);

1;
