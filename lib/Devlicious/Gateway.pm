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

  $self->on(finish => sub {
    delete $backends->{$page};
  });
};

websocket '/devtools/page/:page' => sub {
  my $self = shift;
  my $page = $self->stash('page');

  if (my $backend = $backends->{$page}) {
    Mojo::IOLoop->stream($self->tx->connection)->timeout(0);
    $backend->connect_client($self);
  } else {
    $self->render_not_found;
  }
};

1;

__DATA__

@@ index.html.ep
<h1>Devlicious</h1>

% if (%$backends) {
  <h2>Connected backends</h2>
  <ul>
%   for my $page (keys %$backends) {
      <li>
        <%= link_to($backends->{$page}->name, devtools_url($page)) %>
%       if (my $client = $backends->{$page}->client) {
          (client connected: <%= $client->tx->remote_address %>)
%       }
      </li>
%   }
  </ul>
% } else {
  <h2>No backends connected</h2>
  <p>Please add the Devlicious plugin to your application:</p>
  <pre><code>plugin 'Devlicious'</code></pre>
% }

