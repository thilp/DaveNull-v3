package TestFor::DaveNull::Email;
use Test::Roo::Role;
use MooX::Types::MooseLike::Base qw/ ConsumerOf InstanceOf Str ArrayRef /;
use Email::MIME;
use Class::Load 'load_class';
use DaveNull::Email;

has raw_email => ( # to build DaveNull::Email and Email::MIME
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has structure => (    # expected output for ->structure()
    is       => 'ro',
    isa      => ArrayRef,
    required => 1,
);

has specialized_class => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has mail => (
    is  => 'rw',
    isa => ConsumerOf['DaveNull::Email'],
);

has em => (
    is  => 'lazy',
    isa => InstanceOf['Email::MIME'],
);

sub _build_em { Email::MIME->new( $_[0]->raw_email ) }

before setup => sub {
    my $self = shift;
    load_class( $self->specialized_class );
};

test 'object creation' => sub {
    my $self = shift;
    can_ok( 'DaveNull::Email', 'instantiate' );

    {
        my $mail = DaveNull::Email->instantiate( $self->raw_email );
        isa_ok( $mail, $self->specialized_class );
        $self->mail($mail);
    }

    {
        my $mail = new_ok( $self->specialized_class, [ $self->raw_email ] );
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

test 'headers' => sub {
    my $self = shift;
    can_ok( $self->mail, 'headers' );
    my @headers = $self->em->header_obj->header_pairs;
    is_deeply( $self->mail->headers, \@headers, 'headers listed as expected' );
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

1;
