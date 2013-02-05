package Devlicious::Client::Runtime;
use Mojo::Base -base;

use Scalar::Util qw/blessed reftype looks_like_number/;

has 'client';
sub send { shift->client->send(@_) }

has 'app';

has package => sub {
  my $self = shift;
  my $name = "Devlicious::Client::Runtime::_".int(rand(1000));
  my $app = $self->app;
  eval "package $name; sub app { \$app }";
  $name;
};

sub Runtime_evaluate {
  my ($self, $params, $cb) = @_;
  my $res;

  if ($params->{objectGroup} ne 'completion') {
    my $package = $self->package;
    $res = eval "package $package;".$params->{expression};
  }

  $cb->(
    {
      result => $self->convert($@ || $res),
      wasThrown => $@ ? Mojo::JSON->true : Mojo::JSON->false
    }
  );
}

sub object_id { ++shift->{object_id} }
has objects => sub { {} };

sub convert {
  my ($self, $val) = @_;

  return undef unless defined $val;

  my $type = reftype $val;

  if (!$type) {
    if (looks_like_number $val) {
      return {type => "number", value => 0+$val };
    } else {
      return {type => "string", value => "".$val };
    }
  }

  my $id = "".$self->object_id;
  $self->objects->{$id} = $val;

  if ($type eq 'HASH') {
    {
      type => "object",
      objectId => $id,
      className => blessed $val,
      description => "".$val,
    }
  } elsif ($type eq 'ARRAY') {
    {
      type => "object",
      objectId => $id,
      className => "Array",
      description => "".$val,
      subtype => "array",
    }
  }
}

sub Runtime_getProperties {
  my ($self, $params, $cb) = @_;
  my $val = $self->objects->{$params->{objectId}};
  my @props;

  my $type = reftype $val;

  if ($type eq 'HASH') {
    for my $key (keys %$val) {
      push @props, {
        name => $key,
        configurable => Mojo::JSON->false,
        enumerable => Mojo::JSON->true,
        value => $self->convert($val->{$key}),
      };
    }
  } elsif ($type eq 'ARRAY') {
    my $i = 0;
    for (@$val) {
      push @props, {
        name => "".$i++,
        configurable => Mojo::JSON->false,
        enumerable => Mojo::JSON->true,
        value => $self->convert($_),
      }
    }
  }

  $cb->({result => \@props});
}

1;

