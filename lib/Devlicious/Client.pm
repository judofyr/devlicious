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

my $JSON = Mojo::JSON->new;
has [qw/ua tx/];
has log => sub { Mojo::Log->new };
has gateway => 'ws://localhost:9000';

has name => 'Devlicious';

has network => sub {
  my $self = shift;
  weaken $self;
  Devlicious::Client::Network->new(client => $self);
};

has console => sub {
  my $self = shift;
  weaken $self;
  Devlicious::Client::Console->new(client => $self);
};

has dom => sub {
  my $self = shift;
  weaken $self;
  Devlicious::Client::DOM->new(client => $self);
};

has handlers => sub {
  my $self = shift;
  [$self, $self->network, $self->console, $self->dom];
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

    $self->send_meta({name => $self->name});

    $tx->on(message => sub {
      $self->on_message(pop);
    });

    $tx->on(finish => sub {
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

