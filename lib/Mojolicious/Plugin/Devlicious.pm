package Mojolicious::Plugin::Devlicious;
use Mojo::Base 'Mojolicious::Plugin';
use Devlicious;


sub register {
  my ($self, $app, $config) = @_;

  my $devlicious = Devlicious->new($config || {});
  $devlicious->ua($app->ua)->log($app->log)->name(ref $app);
  $devlicious->watch_ua($app->ua);
  $devlicious->watch_log($app->log);
  $devlicious->connect;
}

1;

