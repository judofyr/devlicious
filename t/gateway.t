use Test::More;
use Test::Mojo;
use strict;
use warnings;

my $w;
sub done { $w = 1 }
sub w {
  my $start = time;

  until ($w) {
    Mojo::IOLoop->one_tick;
    if (time - $start > 2) {
      BAIL_OUT("Timeout");
    }
  }

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
$btx->send('{"hello":"world"}');

$ctx->once(message => sub {
  my $msg = pop;
  is $msg, '{"hello":"world"}';
  done;
});

w;

# Client to backend
$ctx->send('{"hello":"world"}');
$btx->once(message => sub {
  my $msg = pop;
  is $msg, '{"hello":"world"}';
  done;
});

w;

# Antother client connects

# Wait until the current client has been (properly) disconnected
$ctx->once(finish => \&done);

# Connect a new client
$t->ua->websocket('/devtools/page/1', sub {
  $ctx = pop;
  ok !$ctx->error, $ctx->error;
});

w;

# Close the client
$ctx->finish;
$btx->once(message => sub {
  my $msg = pop;
  is $msg, '{"method":"disable"}', "Backend gets disconnect message";
  done;
});

w;

# Close the backend
$btx->once(finish => \&done);
$btx->finish;
w;

$t->ua->get('/', sub {
  my $tx = pop;
  ok !$tx->error, $tx->error;
  like $tx->res->body, qr/No backends/;
  done;
});

w;

done_testing;

