use Mojolicious::Lite;
use lib 'lib';

plugin 'Devlicious';

get '/' => sub {
  my $self = shift;
  $self->ua->get('http://bbc.co.uk/', sub { });
};

app->start;

