use Test::Roo;
use Text::Tabs;
use lib 't/lib';

with 'TestFor::DaveNull::Email';

use DaveNull::Email::Singlepart;

test 'body' => sub {
    my $self    = shift;
    my $witness = expand( $self->em->body_str );
    is $self->mail->body, $witness,
      'body is like Email::MIME::body_str with tabs expanded';
};

test 'nextline and lineno' => sub {
    my $self = shift;

    my @witness = split /\n/ => expand( $self->em->body_str );
    for my $i ( 0 .. @witness - 1 ) {
        is $self->mail->lineno, $i, "lineno returns $i";
        is $self->mail->nextline, $witness[$i],
          qq{nextline returns "$witness[$i]"};
    }

    is $self->mail->nextline, undef, 'nextline returns undef when done';

    is $self->mail->lineno, @witness,
      "lineno does not increase when done";
};

run_me({
        raw_email         => do { local $/; <DATA> },
        structure         => ['text/plain'],
        specialized_class => 'DaveNull::Email::Singlepart',
});

done_testing();

__DATA__
MIME-Version: 1.0
Sender: FOO@example.com
Received: Thu, 5 Sep 2013 17:15:57 -0700 (PDT)
Date: Fri, 6 Sep 2013 02:15:57 +0200
Delivered-To: BAR@example.com
Message-ID: <CAKzV8EwhF_jjfh5O2jwWLUj5rcz7=0yV=wGWSaRXs7Y1YKHZ2Q@example.com>
Subject: Test
From: FOO <FOO@example.com>
To: BAR@example.com
Content-Type: text/plain; charset=ISO-8859-1

Hello BAR.

Love,

-- 
FOO
