use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Devlicious',
  VERSION_FROM => 'lib/Devlicious.pm',
  ABSTRACT     => 'Chrome DevTools for Mojolicious',
  AUTHOR       => 'Magnus Holm <judofyr@gmail.com>',
  LICENSE      => 'mit',
  PREREQ_PM    => {'Mojolicious' => '3.00'},
  META_MERGE   => {
    resources => {
      homepage    => 'http://github.com/judofyr/devlicious',
      license     => 'http://opensource.org/licenses/MIT',
      repository  => 'http://github.com/judofyr/devlicious',
      bugtracker  => 'http://github.com/judofyr/devlicious/issues'
    },
    no_index => {directory => ['t', 'examples']}
  },
  EXE_FILES => ['script/devlicious'],
  test      => {TESTS => 't/*.t'}
);
