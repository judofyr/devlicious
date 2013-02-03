package Devlicious::Client::DOM;
use Mojo::Base -base;

has 'client';
sub send { shift->client->send(@_) }

has [qw/config route/];

my $ELEMENT_NODE = 1;
my $ATTRIBUTE_NODE = 2;
my $TEXT_NODE = 3;
my $CDATA_SECTION_NODE = 4;
my $ENTITY_REFERENCE_NODE = 5;
my $ENTITY_NODE = 6;
my $PROCESSING_INSTRUCTION_NODE = 7;
my $COMMENT_NODE = 8;
my $DOCUMENT_NODE = 9;
my $DOCUMENT_TYPE_NODE = 10;
my $DOCUMENT_FRAGMENT_NODE = 11;
my $NOTATION_NODE = 12;

sub node_id { ++shift->{node_id} }
has mapping => sub { {} };

has doc_node => sub {
  my $self = shift;
  {
    nodeId => $self->node_id,
    nodeType => $DOCUMENT_NODE,
    nodeName => '#document',
    children => [$self->mojo_node],
  }
};

has mojo_node => sub {
  my $self = shift;
  {
    nodeId => $self->node_id,
    nodeType => $ELEMENT_NODE,
    nodeName => 'mojo',
    children => [$self->config_node, $self->route_node],
  }
};

sub DOM_getDocument {
  my ($self, $params, $cb) = @_;
  $cb->({root => $self->doc_node});
}

sub DOM_requestChildNodes {
  my ($self, $params, $cb) = @_;
  my $id = $params->{nodeId};
  my $mapping = $self->mapping->{$id};
  return $cb->() unless $mapping;

  my ($type, @rest) = @$mapping;
  my $meth = $type."_children";
  my @nodes = $self->$meth(@rest);

  $self->send(
    {
      method => 'DOM.setChildNodes',
      params => {
        parentId => int($id),
        nodes => \@nodes,
      }
    }
  );

  $cb->();
}

has config_node => sub {
  my $self = shift;
  $self->build_config_node($self->config);
};

sub build_config_node {
  my ($self, $value, $key) = @_;

  my $id = $self->node_id;
  my $node = {
    nodeId => $id,
    nodeType => $ELEMENT_NODE,
    nodeName => "config",
    attributes => [],
  };

  my $type = ref($value) // '';

  push @{$node->{attributes}}, key => $key if $key;
  push @{$node->{attributes}}, type => lc($type) if $type;


  if ($type) {
    $self->mapping->{$id} = [config => $value];
    $node->{childNodeCount} = $type eq 'HASH' ? (keys %$value) : (@$value);
  } else {
    $node->{children} = [{
      nodeId => $self->node_id,
      nodeType => $TEXT_NODE,
      nodeName => '#text',
      nodeValue => "".$value,
    }];
  }

  $node;
}

sub config_children {
  my ($self, $config) = @_;

  if (ref $config eq 'HASH') {
    map {
      $self->build_config_node($config->{$_}, $_);
    } keys %$config;
  } else {
    map {
      $self->build_config_node($_);
    } @$config;
  }
}

has route_node => sub {
  my $self = shift;
  $self->build_route_node($self->route);
};

sub build_route_node {
  my ($self, $route) = @_;

  my $id = $self->node_id;
  my $node = {
    nodeId => $id,
    nodeType => $ELEMENT_NODE,
    nodeName => "route",
    childNodeCount => scalar(@{$route->children}),
    attributes => [],
  };

  $self->mapping->{$id} = [route => $route];

  my $attr = $node->{attributes};

  my $pattern = $route->pattern;
  push @$attr, pattern => $pattern->pattern if $pattern->pattern;
  push @$attr, name => $route->name if $route->name;
  push @$attr, bridge => "1" if $route->inline;

  for my $key (keys %{$pattern->defaults}) {
    push @$attr, "default-$key" => $pattern->defaults->{$key};
  }

  $node;
}

sub route_children {
  my ($self, $route) = @_;

  map { $self->build_route_node($_) } @{$route->children};
}

1;
