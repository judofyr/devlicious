package Devlicious::Client::Console;
use Mojo::Base -base;

has 'client';
sub send { shift->client->send(@_) }

has enabled => 0;
has logs => sub { [] };

has message_cb => sub {
  my $self = shift;
  sub {
    my ($log, $level, @lines) = @_;
    $self->log_message($level, @lines);
  }
};

sub watch_log {
  my ($self, @log) = @_;
  push $self->logs, @log;

  if ($self->enabled) {
    for my $log (@log) {
      $log->on(message => $self->message_cb);
    }
  }
}

sub Console_enable {
  my $self = shift;
  return if $self->enabled;
  $self->enabled(1);

  for my $log (@{$self->logs}) {
    $log->on(message => $self->message_cb);
  }
}

sub Console_disable {
  my $self = shift;
  return unless $self->enabled;
  $self->enabled(0);

  for my $log (@{$self->logs}) {
    $log->unsubscribe(message => $self->message_cb);
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

1;
