package DaveNull::Email;
# ABSTRACT: Encapsulate Email::MIME logic for Dave, with extra stuff.

# VERSION

use Moo;
use MooX::Types::MooseLike::Base qw/ InstanceOf ArrayRef Str /;
use Carp qw/ confess /;
use Params::Util qw/ _STRING /;
use Email::MIME 1.910;

use namespace::clean;

=head1 SYNOPSIS

    my $email     = DaveNull::Email->new("...");
    my @headers   = $email->headers;
    my $ct        = $email->content_type;
    my $structure = $email->mime_struct;

    # same as if ($email->isa('DaveNull::Email::Multipart'))
    while ( $email->is_multipart ) {
        ($email) = $email->subparts;
    }
    # now $email is the first non-multipart part of the message

    print $email->body;    # may throw an exception: see Email::MIME::body_str

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

=method new( $string )

If C<$string> is a string containing a single-part email (for instance, one of
its headers is "Content-Type: text/plain"), returns a
DaveNull::Email::Singlepart object.

If C<$string> is a multipart email (for instance, one of its headers is
"Content-Type: multipart/mixed"), returns a DaveNull::Email::Multipart object.

Otherwise, dies.

=cut

around new => sub {
    my $orig = shift;
    my $self = shift;
    my $mail = do {
        my $str = _STRING(shift)
          or confess 'Needs an email to build a ' . __PACKAGE__;
        Email::MIME->new($str);
    };
    my @subparts = $mail->subparts;
    @subparts
      ? DaveNull::Email::Multipart->new(
        emailmime => $mail,
        subparts  => \@subparts
      )
      : DaveNull::Email::Singlepart->new( emailmime => $mail );
};

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
    is      => 'ro',
    isa     => ArrayRef[Str],
    lazy    => 1,
    builder => 1,
);

sub _build_headers { [ $_[0]->emailmime->header_obj->header_pairs ] }

=attr content_type

Returns the "type/subtype" of this email, as extracted from the C<Content-Type>
header value.

=cut

has content_type => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => 1,
);

sub _build_content_type {
    my ($ct) = $_[0]->emailmime->content_type =~ m{ \A ( [^;]+ ) }x;
    $ct
}

=attr structure

A representation of this email's MIME structure.

For single-part emails, this attribute is an arrayref containing only one
string (the value of the C<content_type> attribute).

For multipart emails, this attribute is an arrayref containing the content of
each subpart's C<structure> attribute. For instance, take a common
C<"multipart/alternative"> email with only two subparts:
C<"text/plain; charset=UTF-8"> and C<"text/html">.
Its C<structure> argument will be C<< [ 'text/plain', 'text/html' ] >>.
If one of the subparts is a C<"multipart"> itself, there will be an arrayref
in this attribute's arrayref.

When you subclass DaveNull::Email (you're writing DaveNull::Email::NoParts,
maybe?), you must provide a C<_build_structure> builder method.

=cut

has structure => (
    is      => 'ro',
    isa     => ArrayRef,
    lazy    => 1,
    builder => 1,
);

sub _build_structure { confess "Override me!" }

1;
