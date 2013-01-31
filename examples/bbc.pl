use Mojolicious::Lite;
use FindBin;
use lib "$FindBin::Bin/../lib";

plugin 'Devlicious';

get '/' => sub {
  my $self = shift;
  $self->render_later;

  $self->ua->get('http://www.bbc.co.uk/', sub {
    $self->render_text(pop->res->dom->at('title')->text);
  });
};

app->start;

