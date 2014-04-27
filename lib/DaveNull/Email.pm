package DaveNull::Email;
# ABSTRACT: Encapsulates Email::MIME logic for Dave, with extra stuff.

# VERSION

use Moo::Role;
use MooX::Types::MooseLike::Base qw/ InstanceOf ArrayRef Str /;
use Carp qw/ confess /;
use Params::Util qw/ _STRING _CLASSISA /;
use Email::MIME 1.910;
use Safe::Isa;
use Class::Load qw/ load_class /;

use namespace::clean;

=head1 SYNOPSIS

    my $email     = DaveNull::Email->instantiate("...");
    my @headers   = $email->headers;
    my $ct        = $email->content_type;
    my $structure = $email->structure;

    # same as $email->isa('DaveNull::Email::Multipart')
    while ( $email->is_multipart ) {
        ($email) = @{ $email->subparts };
    }
    # now $email is the first non-multipart part of the message

    print $email->body;

    # Or print it line by line
    while ( my $line = $email->nextline ) {
        say "Line: $line";
        say "Line number: ", $email->lineno;
    }

=head1 DESCRIPTION

General representation of an email in Dave. It encapsulates two subclasses:
DaveNull::Email::Singlepart and DaveNull::Email::Multipart. When you ask for a
DaveNull::Email (using C<new> or the C<subparts> method from
DaveNull::Email::Multipart), you actually get an instance from one of these
two subclasses.

If you prefer, you can always fallback to using the underlying Email::MIME
object by using the C<emailmime> attribute.

=cut

=method instantiate( $string ), new( $emailmime )

This is a I<class> method.

If C<$string> is a string containing a single-part email (for instance, one of
its headers is "Content-Type: text/plain"), returns a
DaveNull::Email::Singlepart object.

If C<$string> is a multipart email (for instance, one of its headers is
"Content-Type: multipart/mixed"), returns a DaveNull::Email::Multipart object.

If C<$emailmime> is a L<Email::MIME> object, returns the corresponding
DaveNull::Email subclass.

Otherwise, dies.

=cut

sub _mk_em {
    my $arg = shift or confess 'Expecting a string or Email::MIME object';
    $arg->$_isa('Email::MIME') ? $arg : Email::MIME->new($arg);
}

sub instantiate {
    my $mail = _mk_em( $_[1] );
    my $subclass =
      __PACKAGE__ . '::' . ( $mail->subparts ? 'Multipart' : 'Singlepart' );
    load_class($subclass);
    $subclass->new( emailmime => $mail );
}

=attr emailmime

Returns the underlying L<Email::MIME> object. Read-only.

=cut

has emailmime => (
    is       => 'ro',
    isa      => InstanceOf['Email::MIME'],
    required => 1,
);

=attr headers

A list of the email headers.

This list is composed of pairs "header name"/"header value", but this is not a
hash since some headers may appear more than once. As a side-benefit, the
order in this list is the same as in the email.

=cut

has headers => (
    is      => 'lazy',
    isa     => ArrayRef[Str],
);

sub _build_headers { [ $_[0]->emailmime->header_obj->header_pairs ] }

=attr content_type

Returns the "type/subtype" of this email, as extracted from the C<Content-Type>
header value.

=cut

has content_type => (
    is      => 'lazy',
    isa     => Str,
);

sub _build_content_type {
    my ($ct) = $_[0]->emailmime->content_type =~ m{ \A ( [^;]+ ) }x;
    $ct
}

=attr structure

A representation of this email's MIME structure.

For single-part emails, this attribute is an arrayref containing only one
element (the value of the C<content_type> attribute).

    # Say $email is a DaveNull::Email::Singlepart object.
    # $email->structure could be:
    [ 'text/plain' ]

For multipart emails, this attribute is an arrayref containing the value of
the C<content_type> attribute as first element, then an arrayref as second
argument. This nested arrayref is the concatenation of the C<structure>
attribute for each direct subpart.

For instance, take a common C<"multipart/alternative"> email with only two
subparts: C<"text/plain; charset=UTF-8"> and C<"text/html">:

    # Say $email is a DaveNull::Email::Multipart object.
    # $email->structure could be:
    [ 'multipart/alternative', [ 'text/plain', 'text/html' ] ]

    # or even, with nested "multipart" subparts:
    [
        'multipart/mixed',
        [
            'text/plain',
            'multipart/alternative', [ 'text/plain', 'text/html' ],
        ]
    ]


=cut

has structure => (
    is      => 'lazy',
    isa     => ArrayRef,
);

sub _build_structure {
    [
        $_[0]->is_multipart
        ? (
            $_[0]->content_type,
            [ map { @{ $_->structure } } @{ $_[0]->subparts } ]
          )
        : $_[0]->content_type
    ];
}

=method is_multipart()

Shortcut for C<< isa('DaveNull::Email::Multipart') >>.

=cut

sub is_multipart { $_[0]->isa('DaveNull::Email::Multipart') }

1;
