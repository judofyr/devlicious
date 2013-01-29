package Devlicious::Gateway;
use Mojolicious::Lite;

my $backends = {};
my $pageid = 0;

get '/' => sub {
  my $self = shift;
  $self->stash(backends => [keys %$backends]);
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
  $self->rendered(101) if $self->tx->is_websocket;

  my $page = ++$pageid;
  $backends->{$page} = $self;

  $self->on(finish => sub {
    warn "finish";
    delete $backends->{$page};
  });
};

websocket '/devtools/page/:page' => sub {
  my $self = shift;
  my $page = $self->stash('page');
  Mojo::IOLoop->stream($self->tx->connection)->timeout(0);

  my $backend = $backends->{$page};

  $self->on(message => sub {
    warn $_[1];
    $backend->send(pop)
  });

  $backend->on(message => sub {
    warn $_[1];
    $self->send(pop);
  });
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
% for my $backend (@$backends) {
  <li><%= link_to($backend, devtools_url($backend)) %></li>
% }
</ul>




