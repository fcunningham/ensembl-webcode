# $Id$

package EnsEMBL::Web::Configuration;

use strict;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $page, $hub, $builder, $data) = @_;
  
  my $self = {
    page    => $page,
    hub     => $hub,
    builder => $builder,
    object  => $builder->object,
    _data   => $data,
    cl      => {}
  };
  
  bless $self, $class;
  
  $self->init;
  $self->add_external_browsers;
  $self->modify_tree;
  $self->set_default_action;
  $self->set_action($hub->action, $hub->function);
  $self->modify_page_elements;
  
  return $self;
}

# Get configurable components from a specific action/function combination
sub new_for_components {
  my ($class, $hub, $builder, $data, $action, $function) = @_;
  
  my $self = {
    hub     => $hub,
    _data   => $data,
    builder => $builder,
    object  => $builder->object,
  };
  
  bless $self, $class;
  
  $self->init;
  $self->modify_tree;
  
  return $self->get_configurable_components(undef, $action, $function);
}

sub init {
  my $self       = shift;
  my $hub        = $self->hub;
  my $cache      = $hub->cache;
  my $user       = $hub->user;
  my $session    = $hub->session;
  my $session_id = $session->session_id;
  my $user_tree  = $self->user_tree && ($user || $session_id);
  my $cache_key  = $self->tree_cache_key;
  my $tree       = $cache->get($cache_key) if $cache && $cache_key; # Try to get default tree from cache
  
  if ($tree) {
    $self->{'_data'}{'tree'} = $tree;
  } else {
    $self->populate_tree; # If no user + session tree found, build one
    $cache->set($cache_key, $self->{'_data'}{'tree'}, undef, 'TREE') if $cache && $cache_key; # Cache default tree
  }
  
  $self->user_populate_tree if $user_tree;
}

sub populate_tree         {}
sub modify_tree           {}
sub add_external_browsers {}
sub modify_page_elements  {}
sub caption               {}

sub hub            { return $_[0]->{'hub'};                                   }
sub builder        { return $_[0]->{'builder'};                               }
sub object         { return $_[0]->{'object'};                                }
sub page           { return $_[0]->{'page'};                                  }
sub tree           { return $_[0]->{'_data'}{'tree'};                         }
sub configurable   { return $_[0]->{'_data'}{'configurable'};                 }
sub action         { return $_[0]->{'_data'}{'action'};                       }
sub default_action { return $_[0]->{'_data'}{'default'};                      } # Default action for feature type
sub species        { return $_[0]->hub->species;                              }
sub type           { return $_[0]->hub->type;                                 }
sub short_caption  { return sprintf '%s-based displays', ucfirst $_[0]->type; } # return the caption for the tab
sub user_tree      { return 0;                                                }

sub set_default_action {  
  my $self = shift; 
  $self->{'_data'}->{'default'} = $self->object->default_action if $self->object;
}

sub set_action {
  my $self = shift;
  $self->{'_data'}{'action'} = $self->get_valid_action(@_);
}

sub add_form {
  my ($self, $panel, @T) = @_; 
  $panel->add_form($self->page, @T);
}

sub get_availability {
  my $self = shift;
  my $hub = $self->hub;

  my $hash = { map { ('database:'. lc(substr $_, 9) => 1) } keys %{$hub->species_defs->databases} };
  $hash->{'database:compara'} = 1 if $hub->species_defs->compara_like_databases;
  $hash->{'logged_in'}        = 1 if $hub->user;

  return $hash;
}

# Each class might have different tree caching dependences 
# See Configuration::Account and Configuration::Search for more examples
sub tree_cache_key {
  my ($self, $user, $session) = @_;
  
  my $key = join '::', ref $self, $self->species, 'TREE';

  $key .= '::USER['    . $user->id            . ']' if $user;
  $key .= '::SESSION[' . $session->session_id . ']' if $session && $session->session_id;
  
  return $key;
}

sub get_valid_action {
  my ($self, $action, $function) = @_;
  
  return $action if $action eq 'Wizard';
  
  my $object   = $self->object;
  my $hub      = $self->hub;
  my $tree     = $self->tree;
  my $node_key = join '/', grep $_, $action, $function;
  my $node     = $tree->get_node($node_key);
  
  if (!$node) {
    $node     = $tree->get_node($action);
    $node_key = $action;
  }
  
  $self->{'availability'} = $object->availability if $object;
  
  return $node_key if $node && $node->get('type') =~ /view/ && $self->is_available($node->get('availability'));
  
  foreach ($self->default_action, 'Idhistory', 'Chromosome', 'Genome') {
    $node = $tree->get_node($_);
    
    if ($node && $self->is_available($node->get('availability'))) {
      $hub->problem('redirect', $hub->url({ action => $_ }));
      return $_;
    }
  }
  
  return undef;
}

sub get_node { 
  my ($self, $code) = @_;
  return $self->tree->get_node($code);
}

sub query_string {
  my $self   = shift;
  
  my %parameters = (%{$self->hub->core_params}, @_);
  my @query_string = map "$_=$parameters{$_}", grep defined $parameters{$_}, sort keys %parameters;
  
  return join ';', @query_string;
}

sub create_node {
  my ($self, $code, $caption, $components, $options) = @_;
 
  my $details = {
    caption    => $caption,
    components => $components,
    code       => $code,
    type       => 'view',
    %{$options || {}}
  };
  
  return $self->tree->append($self->tree->create_node($code, $details));
}

sub create_subnode {
  my $self  = shift;
  $_[3]{'type'} = 'subview';
  return $self->create_node(@_,);
}

sub create_submenu {
  my $self = shift;
  splice @_, 2, 0, undef;
  $_[3]{'type'} = 'menu';
  return $self->create_node(@_);
}

sub delete_node {
  my ($self, $code) = @_;
  my $node = $self->tree->get_node($code);
  $node->remove if $node;
}

sub get_configurable_components {
  my ($self, $node, $action, $function) = @_;
  my $hub       = $self->hub;
  my $component = $hub->script eq 'Config' ? $hub->action : undef;
  my $type      = [ split '::', ref $self ]->[-1];
  my @components;
  
  if ($component && !$action) {
    my $module_name = $self->get_module_names('ViewConfig', $type, $component);
    @components = ($component) if $module_name;
  } else {
    $node ||= $self->get_node($self->get_valid_action($action || $hub->action, $function || $hub->function));
    
    if ($node) {
      foreach (reverse grep /::Component::/, @{$node->data->{'components'}}) {
        my ($component) = split '/', [split '::']->[-1];
        my $module_name = $self->get_module_names('ViewConfig', $type, $component);
        push @components, $component if $module_name;
      }
    }
  }
  
  return \@components;
}

sub user_populate_tree {
  my $self        = shift;
  my $hub         = $self->hub;
  my $type        = $hub->type;
  my $all_das     = $hub->get_all_das;
  my $view_config = $hub->get_viewconfig('ExternalData');
  my @active_das  = grep { $view_config->get($_) eq 'yes' && $all_das->{$_} } $view_config->options;
  my $ext_node    = $self->tree->get_node('ExternalData');
  
  foreach (sort { lc($all_das->{$a}->caption) cmp lc($all_das->{$b}->caption) } @active_das) {
    my $source = $all_das->{$_};
    
    $ext_node->append($self->create_subnode("ExternalData/$_", $source->caption,
      [ 'textdas', "EnsEMBL::Web::Component::${type}::TextDAS" ], {
        availability => lc $type, 
        concise      => $source->caption, 
        caption      => $source->caption, 
        full_caption => $source->label
      }
    ));	 
  }
}

1;
