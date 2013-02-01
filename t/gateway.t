use Test::More;
use Test::Mojo;
use strict;
use warnings;

my $w;
sub done { $w = 1 }
sub w {
  Mojo::IOLoop->one_tick until $w;
  $w = undef;
}

my $t = Test::Mojo->new('Devlicious::Gateway');

my ($btx, $ctx);

# Backend
$t->ua->websocket('/connect', sub {
  $btx = pop;
  ok !$btx->error, $btx->error;
  $btx->send('Devlicious:{"name":"DevTest"}', \&done);
});

w;

# Listing
$t->ua->get('/', sub {
  my $tx = pop;
  ok !$tx->error, $tx->error;
  like $tx->res->body, qr/>DevTest</;
  done;
});

w;

# Client
$t->ua->websocket('/devtools/page/1', sub {
  $ctx = pop;
  ok !$ctx->error, $ctx->error;
  done;
});

w;

# Backend to client
$btx->send('{"hello":"world"}', \&done);
$ctx->once(message => sub {
  my $msg = pop;
  is $msg, '{"hello":"world"}';
  done;
});

w;

# Client to backend
$ctx->send('{"hello":"world"}', \&done);
$btx->once(message => sub {
  my $msg = pop;
  is $msg, '{"hello":"world"}';
  done;
});

w;

done_testing;

