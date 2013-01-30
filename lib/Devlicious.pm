package Devlicious;
use Mojo::Base -base;

use Mojo::JSON;
use Mojo::UserAgent;
use Mojo::Log;
use Mojo::Util 'monkey_patch';
use Time::HiRes 'time';

my $JSON = Mojo::JSON->new;
has [qw/ua tx/];
has log => sub { Mojo::Log->new };
has gateway => 'ws://localhost:9000';

has name => 'Devlicious';

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

    if ($self->can($meth)) {
      # Callback for req/res
      my $cb = sub {
        my $res = { id => $obj->{id}, result => pop };
        $self->send($res);
      };

      $self->$meth($params, $cb);
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

## Console

has console_enabled => 0;
has console_logs => sub { [] };
has console_message => sub {
  my $self = shift;
  sub {
    my ($log, $level, @lines) = @_;
    $self->log_message($level, @lines);
  }
};

sub watch_log {
  my ($self, @log) = @_;
  push $self->console_logs, @log;

  if ($self->console_enabled) {
    for my $log (@log) {
      $log->on(message => $self->console_message);
    }
  }
}

sub Console_enable {
  my $self = shift;
  return if $self->console_enabled;

  for my $log (@{$self->console_logs}) {
    $log->on(message => $self->console_message);
  }
}

my $log_mapping = {
  info => 'log',
  warn => 'warning',
  fatal => 'error',
};

sub log_message {
  my ($self, $level, $line) = @_;
  $self->send(
    {
      method => 'Console.messageAdded',
      params => {
        message => {
          level => $log_mapping->{$level} || $level,
          text => $line,
          source => 'other',
        }
      }
    }
  );
}

## Network

has network_enabled => 0;
has network_uas => sub { [] };
has network_start => sub {
  my $self = shift;
  sub { $self->ua_start(pop) }
};

sub watch_ua {
  my ($self, @ua) = @_;
  push $self->network_uas, @ua;

  if ($self->network_enabled) {
    for my $ua (@ua) {
      $ua->on(start => $self->network_start);
    }
  }
}

sub Network_enable {
  my $self = shift;
  return if $self->network_enabled;
  $self->network_enabled(1);

  for my $ua (@{$self->network_uas}) {
    $ua->on(start => $self->network_start);
  }
}

sub ua_start {
  my ($self, $tx) = @_;

  my $reqId = "".++$self->{requestId};

  $self->send(
    {
      method => 'Network.requestWillBeSent',
      params => {
        requestId => $reqId,
        loaderId => "loader",
        documentURL => $tx->req->url->to_abs,
        request => {
          method => $tx->req->method,
          url => $tx->req->url->to_abs,
          headers => $tx->req->headers->to_hash
        },
        timestamp => time,
        initiator => {
          type => 'other'
        },
      }
    }
  );

  $tx->res->content->on(body => sub {
    $self->send(
      {
        method => 'Network.responseReceived',
        params => {
          requestId => $reqId,
          loaderId => "loader",
          timestamp => time,
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
      }
    );
  });

  $tx->res->content->on(read => sub {
    my $bytes = pop;
    $self->send(
      {
        method => 'Network.dataReceived',
        params => {
          requestId => $reqId,
          timestamp => time,
          dataLength => length($bytes),
          encodedDataLength => length($bytes),
        }
      }
    );
  });

  $tx->on(finish => sub {
    $self->send(
      {
        method => 'Network.loadingFinished',
        params => {
          requestId => $reqId,
          timestamp => time,
        }
      }
    );
  });
}

1;

