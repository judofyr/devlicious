package Mojolicious::Plugin::Devlicious;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON;
use Mojo::UserAgent;
use Mojo::Util 'monkey_patch';

my $JSON = Mojo::JSON->new;
has [qw/ua tx/];

sub register {
  my ($self, $app, $config) = @_;

  my $gateway = $config->{gateway} || 'ws://localhost:9000';

  $self->ua($app->ua);
  $self->ua->websocket($gateway . '/connect', sub {
    my $tx = pop;
    Mojo::IOLoop->stream($tx->connection)->timeout(0);
    $self->tx($tx);

    $tx->on(message => sub {
      my $msg = pop;
      my $obj = $JSON->decode($msg);

      if (my $meth = $obj->{method}) {
        $meth =~ s/\./_/;
        my $params = $obj->{params} // {};

        if ($self->can($meth)) {
          my $cb = sub {
            my $res = { id => $obj->{id}, result => pop };
            $self->send($res);
          };

          $self->$meth($params, $cb);
        }
      }
      warn $msg;
    });
  });
}

sub send {
  my ($self, $hash) = @_;
  $self->tx->send($JSON->encode($hash));
}

## Capabilities
my @cant = qw/
  Page_canOverrideDeviceOrientation
  Network_canClearBrowserCache
  Network_canClearBrowserCookies
/;

for my $name (@cant) {
  monkey_patch __PACKAGE__, $name, sub { pop->($JSON->false) };
}

## Network
sub Network_enable {
  my $self = shift;
  $self->ua->on(start => sub {
    my $tx = pop;

    my $event = {
      method => 'Network.requestWillBeSent',
      params => {
        requestId => 1,
        loaderId => "loader",
        documentURL => $tx->req->url->to_abs,
        request => {
          method => $tx->req->method,
          url => $tx->req->url->to_abs,
          headers => $tx->req->headers->to_hash
        },
        timestamp => 1,
        initiator => {
          type => 'other'
        },
      }
    };

    $self->send($event);

    $tx->on(finish => sub {
      $self->send({
        method => 'Network.responseReceived',
        params => {
          requestId => 1,
          loaderId => "loader",
          timestamp => 1,
          type => 'Other',
          response => {
            connectionId => 1,
            connectionReused => $JSON->false,
            headers => $tx->res->headers->to_hash,
            mimeType => $tx->res->headers->content_type,
            status => $tx->res->code,
            statusText => $tx->res->message || $tx->res->default_message,
            url => $tx->req->url->to_abs,
          }
        }
      });

      $self->send({
        method => 'Network.loadingFinished',
        params => {
          requestId => 1,
          timestamp => 1,
        }
      });
    });
  });
}

1;

