package Devlicious::Client::Network;
use Mojo::Base -base;

has 'client';
sub send { shift->client->send(@_) }

has enabled => 0;
has uas => sub { [] };
has transactions => sub { {} };

has start_cb => sub {
  my $self = shift;
  sub { $self->ua_start(pop) }
};

sub watch_ua {
  my ($self, @ua) = @_;
  push $self->uas, @ua;

  if ($self->enabled) {
    for my $ua (@ua) {
      $ua->on(start => $self->start_cb);
    }
  }
}

sub Network_enable {
  my $self = shift;
  return if $self->enabled;
  $self->enabled(1);

  for my $ua (@{$self->uas}) {
    $ua->on(start => $self->start_cb);
  }
}

sub Network_disable {
  my $self = shift;
  return unless $self->enabled;
  $self->enabled(0);

  for my $ua (@{$self->uas}) {
    $ua->unsubscribe(start => $self->start_cb);
  }
}

sub ua_start {
  my ($self, $tx) = @_;

  my $reqId = "".++$self->{requestId};

  $self->transactions->{$reqId} = $tx;

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
            connectionReused => Mojo::JSON->false,
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
    Mojo::IOLoop->timer(60 => sub {
      delete $self->transactions->{$reqId};
    });

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

sub Network_getResponseBody {
  my ($self, $params, $cb) = @_;
  my $reqId = $params->{requestId};

  my $body = "body no longer available";
  my $base64 = Mojo::JSON->false;

  if (my $tx = $self->transactions->{$reqId}) {
    $body = $tx->res->body;
  }

  $cb->({body => $body, base64Encoded => $base64});
}


1;
