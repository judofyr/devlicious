package Devlicious;
use Mojo::Base -base;

our $VERSION  = '0.01';

use Mojo::UserAgent;
use File::Path 'mkpath';
use File::Spec::Functions;
use Archive::Extract;
require Devlicious::Gateway;

my $config_path = catdir($ENV{HOME}, '.devlicious');
my $devtools_path = catdir($config_path, 'devtools');
my $devtools_zip = catdir($config_path, 'devtools_frontend.zip');

my $frontend_url = "http://storage.googleapis.com/chromium-browser-continuous/Mac/%s/devtools_frontend.zip";
my $good_rev = 152100;

sub devtools_installed {
  -d $devtools_path;
}

sub download {
  mkpath($config_path);

  say "Downloading DevTools frontend $good_rev...";
  my $ua = Mojo::UserAgent->new;
  my $tx = $ua->get(sprintf($frontend_url, $good_rev));
  $tx->res->content->asset->move_to($devtools_zip);

  mkpath($devtools_path);
  say "Extracting $devtools_zip...";
  my $ae = Archive::Extract->new(archive => $devtools_zip);
  $ae->extract(to => $devtools_path);

  say "Done.";
}

sub run {
  die "Can't find DevTools in $devtools_path" unless devtools_installed;
  my $app = Devlicious::Gateway->app;
  push @{$app->static->paths}, $config_path;

  local $ENV{MOJO_LISTEN} = 'http://*:9000';
  use Mojolicious::Command::daemon;
  my $daemon = Mojolicious::Command::daemon->new(app => $app);
  $daemon->run(@ARGV);
}

1;

