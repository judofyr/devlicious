package Mojolicious::Plugin::Devlicious;
use Mojo::Base 'Mojolicious::Plugin';
use Devlicious::Client;


sub register {
  my ($self, $app, $config) = @_;

  my $devlicious = Devlicious::Client->new($config || {});
  $devlicious->ua($app->ua)->log($app->log)->name(ref $app);
  $devlicious->watch_ua($app->ua);
  $devlicious->watch_log($app->log);
  $devlicious->dom->config($app->config);
  $devlicious->dom->route($app->routes);
  $devlicious->runtime->app($app);
  $devlicious->connect;
}

1;

