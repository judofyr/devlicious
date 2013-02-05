package Devlicious::Client;
use Mojo::Base -base;

use Mojo::JSON;
use Mojo::UserAgent;
use Mojo::Log;
use Mojo::Util 'monkey_patch';
use Time::HiRes 'time';
use Scalar::Util 'weaken';

use Devlicious::Client::Network;
use Devlicious::Client::Console;
use Devlicious::Client::DOM;
use Devlicious::Client::Runtime;

my $JSON = Mojo::JSON->new;
has [qw/ua tx/];
has log => sub { Mojo::Log->new };
has gateway => 'ws://localhost:9000';

has name => 'Devlicious';

has network => sub {
  my $self = shift;
  my $network = Devlicious::Client::Network->new(client => $self);
  weaken $network->{client};
  $network;
};

has console => sub {
  my $self = shift;
  my $console = Devlicious::Client::Console->new(client => $self);
  weaken $console->{client};
  $console;
};

has dom => sub {
  my $self = shift;
  my $dom = Devlicious::Client::DOM->new(client => $self);
  weaken $dom->{client};
  $dom;
};

has runtime => sub {
  my $self = shift;
  my $runtime = Devlicious::Client::Runtime->new(client => $self);
  weaken $runtime->{client};
  $runtime;
};

has handlers => sub {
  my $self = shift;
  my $res = [$self, $self->network, $self->console, $self->dom, $self->runtime];
  weaken $res->[0];
  $res;
};

sub is_connected { !!shift->tx }

sub connect {
  my $self = shift;

  $self->ua->websocket($self->gateway . '/connect', sub {
    my $tx = pop;
    if ($tx->error) {
      $self->log->debug("Devlicious failed: ".$tx->error);
      return;
    }

    $self->log->debug("Devlicious connected");

    Mojo::IOLoop->stream($tx->connection)->timeout(0);

    $self->tx($tx);
    weaken $self->{tx};

    # Avoid cycle. The UA will have a reference to this callback, this
    # callback closes over $self and $self has a reference back to the
    # UA. It's safe to weaken this refrence when we are connected to the
    # gateway because the IOLoop will (indirectly) have a reference to
    # the UA. When the connection closes, that reference will go away
    # and we need to turn this back into a strong reference.
    weaken $self->{ua};

    $self->send_meta({name => $self->name});

    $tx->on(message => sub {
      $self->on_message(pop);
    });

    $tx->on(finish => sub {
      # Turn it into a strong reference
      $self->{ua} = $self->{ua};
      delete $self->{tx};
      $self->disable;
      $self->log->debug("Devlicious disconnected");
    });
  });
}

sub on_message {
  my ($self, $msg) = @_;
  my $obj = $JSON->decode($msg);

  if (my $meth = $obj->{method}) {
    $meth =~ s/\./_/;
    my $params = $obj->{params} // {};


    for my $handler (@{$self->handlers}) {
      if ($handler->can($meth)) {
        my $cb = sub {
          my $res = { id => $obj->{id}, result => pop };
          $self->send($res);
        };

        $handler->$meth($params, $cb);

        return;
      }
    }
  }
}

sub send_meta {
  my ($self, $obj) = @_;
  $self->tx->send("Devlicious:" . $JSON->encode($obj));
}

sub send {
  my ($self, $obj) = @_;
  $self->tx->send($JSON->encode($obj));
}

sub disable {
  my $self = shift;
  $self->network->Network_disable;
  $self->console->Console_disable;
  delete $self->{dom};
  delete $self->{runtime};
}

## Capabilities

my %capabilities = (
  Page_canOverrideDeviceOrientation => 0,
  Network_canClearBrowserCache      => 0,
  Network_canClearBrowserCookies    => 0,
);

for my $name (keys %capabilities) {
  monkey_patch __PACKAGE__, $name, sub {
    my $cb = pop;
    $cb->($capabilities{$name} ? $JSON->true : $JSON->false);
  };
}

sub watch_log {
  shift->console->watch_log(@_);
}

sub watch_ua {
  shift->network->watch_ua(@_);
}

1;

