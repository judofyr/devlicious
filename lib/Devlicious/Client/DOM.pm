package Devlicious::Client::DOM;
use Mojo::Base -base;

has 'client';
sub send { shift->client->send(@_) }

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
    children => [$self->config_node],
  }
};

has config_mapping => sub { {} };

has config_node => sub {
  my $self = shift;
  $self->build_config_node($self->client->config);
};

sub DOM_getDocument {
  my ($self, $params, $cb) = @_;
  $cb->({root => $self->doc_node});
}

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
    $self->config_mapping->{$id} = $value;
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

sub DOM_requestChildNodes {
  my ($self, $params, $cb) = @_;
  my $config = $self->config_mapping->{$params->{nodeId}};
  return unless $config;

  my @nodes;

  if (ref $config eq 'HASH') {
    for my $key (keys %$config) {
      my $node = $self->build_config_node($config->{$key}, $key);
      push @nodes, $node;
    }
  } else {
    for my $value (@$config) {
      my $node = $self->build_config_node($value);
      push @nodes, $node;
    }
  }

  $self->send(
    {
      method => 'DOM.setChildNodes',
      params => {
        parentId => int($params->{nodeId}),
        nodes => \@nodes,
      }
    }
  );

  $cb->();
}

1;
