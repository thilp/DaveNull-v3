package TestFor::DaveNull::Email;
use Test::Roo::Role;
use MooX::Types::MooseLike::Base qw/ ConsumerOf InstanceOf Str ArrayRef /;
use Email::MIME;
use Class::Load 'load_class';
use DaveNull::Email;

sub mkmail { DaveNull::Email->instantiate($_[0]) }

#-----------------------------------------------------------------------------

# For instance, "DaveNull::Email::Singlepart"
has specialized_class => ( is => 'ro', isa => Str, required => 1 );

# raw_mail's MIME structure (expected output for ->structure)
has structure => ( is => 'ro', isa => ArrayRef, required => 1 );

# source text for the user-provided email
has raw_mail => ( is => 'ro', isa => Str, required => 1 );

# own_mail: email from __DATA__ below
# mail:     user-provided email from raw_mail
has [ qw/ own_mail mail / ] => (
    is  => 'lazy', isa => ConsumerOf['DaveNull::Email'],
);

sub _build_own_mail { mkmail( do { local $/; <DATA> } ) }
sub _build_mail     { mkmail( $_[0]->raw_mail ) }

# Our "witness" Email::MIME instance, corresponding to raw_mail
has em => ( is  => 'lazy', isa => InstanceOf['Email::MIME'] );

sub _build_em { Email::MIME->new( $_[0]->raw_mail ) }

#-----------------------------------------------------------------------------

before setup => sub {
    my $self = shift;
    load_class( $self->specialized_class );
};

#-----------------------------------------------------------------------------

test 'object creation' => sub {
    my $self = shift;

    {
        my $mail = new_ok( $self->specialized_class, [ $self->raw_mail ] );
        is_deeply( $mail, $self->mail,
            $self->specialized_class
              . '::new produces the same thing than Dave::Email::instantiate' );
    }

    {
        my $mail = new_ok( $self->specialized_class, [ $self->em ] );
        is_deeply( $mail, $self->mail,
                'objects constructed from a string and '
              . 'from an Email::MIME are the same' );
    }
};

test 'underlying Email::MIME object' => sub {
    my $self = shift;
    can_ok( $self->mail, 'emailmime' );
    isa_ok( $self->mail->emailmime, 'Email::MIME' );
};

test 'content_type' => sub {
    my $self = shift;
    can_ok( $self->mail, 'content_type' );
    ( my $ct = $self->em->content_type ) =~ s/;.*$//;
    is $self->mail->content_type, $ct,
      'content_type returns the Content-Type header value, '
      . 'but without any parameter';
};

test 'MIME structure' => sub {
    my $self = shift;
    can_ok $self->mail, 'structure';
    is_deeply $self->mail->structure, $self->structure,
      'structure built as expected';
};

test 'is_multipart' => sub {
    my $self = shift;
    can_ok $self->mail, 'is_multipart';
    ok !( $self->mail->is_multipart
        xor $self->mail->isa('DaveNull::Email::Multipart') ),
      'is_multipart equals isa("DaveNull::Email::Multipart")';
};

test 'interactions with headers' => sub {
    my $self = shift;

    # Test headers()
    can_ok( $self->mail, 'headers' );
    my @headers = $self->em->header_obj->header_pairs;
    is_deeply( $self->mail->headers, \@headers, 'headers listed as expected' );

    my %headers = @{ $self->own_mail->headers };
    is $headers{Received},
      'from mr.example.com by X with SMTP id sq7mr41018152vcb; '
      . 'Wed, 23 Apr 2014 01:42:11 -0700 (PDT)',
      'in multiline headers, \n becomes whitespace';

    # Test header($header_name)
    can_ok( $self->own_mail, 'header' );
    is $self->own_mail->header('Sender'), 'FOO@example.com',
      'header("Foo") works fine when there is just one "Foo" header';
    is $self->own_mail->header('delivered-to'), 'BAR@example.com',
      'header() is case-insensitive';
    is $self->own_mail->header('To'), 'BAR@example.com',
      'header("foo") in scalar context returns the first value '
      . 'of multiple "Foo" header';
    is_deeply [ $self->own_mail->header('To') ],
      [ 'BAR@example.com', 'QUUX@example.com' ],
      'header("Foo") in list context returns all "Foo" header values';
    is_deeply [ $self->own_mail->header('tO') ],
      [ 'BAR@example.com', 'QUUX@example.com' ],
      'header() in list context is case-insensitive too';
    is $self->own_mail->header('Z-Nonexistent-Header'), undef,
      'asking for a nonexistent header in scalar context returns undef';
    is_deeply [ $self->own_mail->header('Z-Nonexistent-Header') ], [],
      'asking for a nonexistent header in list context returns an empty list';
};

#-----------------------------------------------------------------------------

1;

__DATA__
MIME-Version: 1.0
Sender: FOO@example.com
Received: from mr.example.com
        by X with SMTP id sq7mr41018152vcb;
        Wed, 23 Apr 2014 01:42:11 -0700 (PDT)
Date: Fri, 6 Sep 2013 02:15:57 +0200
Delivered-To: BAR@example.com
Message-ID: <CAKzV8EwhF_jjfh5O2jwWLUj5rcz7=0yV=wGWSaRXs7Y1YKHZ2Q@example.com>
Subject: Test
From: FOO <FOO@example.com>
To: BAR@example.com
To: QUUX@example.com
Content-Type: text/plain; charset=ISO-8859-1

Hello BAR.

Love,

-- 
FOO
