package Devlicious::Backend;
use Mojo::Base -base;

use Mojo::Log;
use Mojo::JSON;
my $JSON = Mojo::JSON->new;

has 'c';
has 'client';

has 'id';
has name => sub { shift->id };

has log => sub { Mojo::Log->new };

sub setup {
  my $self = shift;
  
  $self->c->on(message => sub {
    my $msg = pop;

    if ($msg =~ s/^Devlicious://) {
      warn "Internal: " . $msg;
      my $obj = $JSON->decode($msg);
      $self->name($obj->{name}) if $obj->{name};
    } elsif ($self->client) {
      warn "Server -> Client: " . $msg;
      $self->client->send($msg);
    } else {
      warn "Server -> Client (dropping): " . $msg;
    }
  });

  $self->c->on(finish => sub {
    $self->disconnect_client if $self->client;
  });
}

sub connect_client {
  my ($self, $client) = @_;
  $self->disconnect_client if $self->client;

  $self->client($client);

  $client->on(message => sub {
    my $msg = pop;
    warn "Client -> Server: " . $msg;
    $self->c->send($msg);
  });

  $client->on(finish => sub {
    $self->client(0);
    $self->c->send('{"method":"disable"}');
  });
}

sub disconnect_client {
  my $self = shift;
  $self->client->finish;
  $self->client(0);
}

1;

