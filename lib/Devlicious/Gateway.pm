package Devlicious::Gateway;
use Mojolicious::Lite;
use lib 'lib';
use Devlicious::Backend;

my $backends = {};
my $pageid = 0;

get '/' => sub {
  my $self = shift;
  $self->stash(backends => $backends);
  $self->render('index');
};

helper devtools_url => sub {
  my ($self, $page) = @_;
  my $url = $self->req->url->to_abs;
  $self->url_for('/devtools/devtools.html')->query(host => $url->host.':'.$url->port, page => $page);
};

websocket '/connect' => sub {
  my $self = shift;
  Mojo::IOLoop->stream($self->tx->connection)->timeout(0);

  my $page = ++$pageid;
  my $backend = Devlicious::Backend->new(
    c => $self,
    id => $page
  );

  $backend->setup;
  $backends->{$page} = $backend;
};

websocket '/devtools/page/:page' => sub {
  my $self = shift;
  my $page = $self->stash('page');
  Mojo::IOLoop->stream($self->tx->connection)->timeout(0);

  if (my $backend = $backends->{$page}) {
    $backend->connect_client($self);
  }
};

use Mojolicious::Static;
my $devtools = Mojolicious::Static->new;
push $devtools->paths, app->home->rel_dir('../../devtools_frontend');

get '/devtools/*path' => sub {
  my $self = shift;
  $devtools->dispatch($self) || $self->render_not_found;
};

app->start;

1;

__DATA__

@@ index.html.ep
<h2>Backend</h2>
<ul>
% for my $page (keys %$backends) {
  <li><%= link_to($backends->{$page}->name, devtools_url($page)) %></li>
% }
</ul>




