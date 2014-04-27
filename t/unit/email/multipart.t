use Test::Roo;
use Text::Tabs;
use lib 't/lib';

with 'TestFor::DaveNull::Email';

use DaveNull::Email::Multipart;

test 'subparts' => sub {
    my $self = shift;

    # First depth: multipart/mixed
    my $subparts = $self->mail->subparts;
    is_deeply [ map { ref } @$subparts ],
      ['DaveNull::Email::Multipart'],
      'only one subpart, which is itself a DaveNull::Email::Multipart';
    is $subparts->[0]->content_type, 'multipart/alternative',
      'subpart is multipart/alternative';

    # Second depth: multipart/alternative
    $subparts = $subparts->[0]->subparts;
    is_deeply [ map { ref } @$subparts ],
      [ 'DaveNull::Email::Singlepart', 'DaveNull::Email::Singlepart' ],
      'two sub-subparts, which are DaveNull::Email::Singleparts';
    is $subparts->[0]->content_type, 'text/plain',
      'first sub-subpart is text/plain';
    is $subparts->[1]->content_type, 'text/html',
      'second sub-subpart is text/html';
};

run_me({
    raw_email => do { local $/; <DATA> },
    structure => [
        'multipart/mixed',
        [ 'multipart/alternative', [ 'text/plain', 'text/html' ] ]
    ],
    specialized_class => 'DaveNull::Email::Multipart',
});

done_testing();

__DATA__
Delivered-To: FOO@example.com
Received: by X.X.X.X with SMTP id zt7csp1694lbb;
        Wed, 23 Apr 2014 01:42:11 -0700 (PDT)
X-Received: from mr.example.com ([X.X.X.X])
        by X.X.X.X with SMTP id sq7mr41018152vcb.5.1398242531381 (num_hops = 1);
        Wed, 23 Apr 2014 01:42:11 -0700 (PDT)
X-Received: by X.X.X.X with SMTP id sq7mr41375762vcb.5.1398242530681;
        Wed, 23 Apr 2014 01:42:10 -0700 (PDT)
X-Forwarded-To: FOO@example.com
X-Forwarded-For: BAR@example.com FOO@example.com
Delivered-To: BAR@example.com
Received: by X.X.X.X with SMTP id df2csp74090vcb;
        Wed, 23 Apr 2014 01:42:10 -0700 (PDT)
X-Received: by X.X.X.X with SMTP id d30mr43809445qgd.62.1398242529657;
        Wed, 23 Apr 2014 01:42:09 -0700 (PDT)
Return-Path: <baz@e.example.com>
Received: from omp.e.example.com (omp.e.example.com. [X.X.X.X])
        by mx.example.com with ESMTP id p8si125342qag.X.X.X.X.01.42.08
        for <BAR@example.com>;
        Wed, 23 Apr 2014 01:42:09 -0700 (PDT)
Received-SPF: pass (example.com: domain of baz@e.example.com designates X.X.X.X as permitted sender) client-ip=X.X.X.X;
Authentication-Results: mx.example.com;
       spf=pass (example.com: domain of baz@e.example.com designates X.X.X.X as permitted sender) smtp.mail=baz@e.example.com;
       dkim=pass header.i=baz@e.example.com;
       dmarc=pass (p=REJECT dis=NONE) header.from=example.com
DKIM-Signature: v=1; a=rsa-sha1; c=relaxed/relaxed; s=baz; d=e.example.com;
 h=MIME-Version:Content-Type:Date:To:From:Reply-To:Subject:List-Unsubscribe:Message-ID; i=baz@e.example.com;
 bh=RJSZp/avd5UePVGhblV5IPLo1Ug=;
 b=xSzPphQI/0/Mo50Tcs5X3xtQv7+uJmou70FgwjNzH9jJ76W4ZPveyG7dhPYU5OVMuHwyT6bPKeE2
   HJ4Ow3MC5WaVzI9wOJOVC3vgR+tMrlfiKNDSuybEKkz9TEwbX8dLDAhNsiIh9uaUWOoRR2gVtDg+
   uA805RFIf179u6oROKs=
DomainKey-Signature: a=rsa-sha1; c=nofws; q=dns; s=baz; d=e.example.com;
 b=VQ8RFcgbOjFcovIN0LPzeZgL1pqLX8x5JQ+C0qm/2udhb8hF76LsSIRzzcgj3ajsY2Aj0tLwRrh8
   yrpXCAlgQl+Us/cQ75151kU/SfyFfPW1hziWHWKPt/DH5SlcTboikUJvpTJxiAVeKqY7dZJzoOB3
   uBgXOOnWblyPbHNJNg4=;
Received: by omp.e.example.com id hatue21hdbgi for <BAR@example.com>; Wed, 23 Apr 2014 00:35:34 -0700 (envelope-from <baz@e.example.com>)
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="----msg_border_Hnu0OVpx0U"
Date: Wed, 23 Apr 2014 00:35:34 -0700
To: BAR@example.com
From: "Baz" <baz@e.example.com>
Reply-To: "Baz" <donotreply@e.example.com>
Subject: Foo, essayez gratuitement Baz pendant un mois
List-Unsubscribe: <mailto:unsubscribe@example.com?subject=List-Unsubscribe>
X-sgxh1: lopIHmlQtLQiHnLxnuHptQJhu
X-rext: 4.interact5.Eh0Pb0ItWTq3LJXl6kK7BsaJuh1KQ_JLE-Q
X-cid: baz.3752
Require-Recipient-Valid-Since: BAR@example.com; Sun, 4 Nov 2012 22:41:00 -0800
Message-ID: <X.X.X.X.1CF5EC69D1C1E46.0@omp.e.example.com>

This is a multi-part message in MIME format.

------msg_border_Hnu0OVpx0U
Date: Wed, 23 Apr 2014 00:35:34 -0700
Content-Type: multipart/alternative; boundary="----alt_border_jFpqdkQx9y_1"



------alt_border_jFpqdkQx9y_1
Content-Type: text/plain;
    charset="UTF-8"
Content-Transfer-Encoding: quoted-printable

Please view this email in a browser.

Copyright 2014, Baz Corporation=2E All rights reserved=2E Baz Cor=
p=2E 2027 Stierlin Court, Mountain View CA 94043
=2E

------alt_border_jFpqdkQx9y_1
Content-Type: text/html;
    charset="UTF-8"
Content-Transfer-Encoding: quoted-printable

<=21DOCTYPE html PUBLIC =22-//W3C//DTD XHTML 1=2E0 Transitional//EN=22 =22h=
ttp://www=2Ew3=2Eorg/TR/xhtml1/DTD/xhtml1-transitional=2Edtd=22>
<html xmlns=3D=22http://www=2Ew3=2Eorg/1999/xhtml=22>
<head>
<meta http-equiv=3D=22Content-Type=22 content=3D=22text/html; charset=3DUTF=
-8=22 />
</head>
<title>Baz</title><body>
<p>Hello boy</p>
</body>
</html>

------alt_border_jFpqdkQx9y_1--

------msg_border_Hnu0OVpx0U--
