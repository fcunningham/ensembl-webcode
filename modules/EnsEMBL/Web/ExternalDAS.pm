#!/usr/local/bin/perl

package EnsEMBL::Web::ExternalDAS;
use strict;

sub new {
  my( $class, $proxiable ) = @_;
  my $self = { 
    'proxiable'  => $proxiable,
    'configs'  => {},
    'data'     => {},
    'defaults' => {
      'LABELFLAG'      => 'u',
      'STRAND'         => 'b',
      'DEPTH'          => '4',
      'GROUP'          => '1',
      'DEFAULT_COLOUR' => 'grey50',
      'STYLESHEET'     => 'Y',
      'SCORE' => 'N'
    },
  };
  bless($self,$class);
  $self->get_sources(); ## Get configurations...
  return $self;
}

sub getConfigs {
  my( $self, @Q ) = @_;
  while( my($key,$value) = splice(@Q,0,2) ) {
    $self->{'configs'}{$key} = $self->{'proxiable'}->user_config_hash( $value );
  }
}

sub add_das_source {
  my( $self, $href ) = @_;

  $self->amend_source( {
    'enable'     => $href->{enable},
    'mapping'    => $href->{mapping},
    'select'     => $href->{select},
    'on'         => 'on',
    'name'       => $href->{name},
    'color'      => $href->{color},           
    'col'        => $href->{col},           
    'help'       => $href->{help},           
    'mapping'    => $href->{mapping},           
    'active'     => $href->{active},           
    'URL'        => $href->{url},
    'dsn'        => $href->{dsn},
    'linktext'   => $href->{linktext},
    'linkurl'    => $href->{linkurl},
    'caption'    => $href->{caption},
    'label'      => $href->{label},
    'url'        => $href->{url},
    'protocol'   => $href->{protocol},
    'domain'     => $href->{domain},
    'type'       => $href->{type},
    'labelflag'  => $href->{labelflag},
    'strand'     => $href->{strand},
    'group'      => $href->{group},
    'depth'      => $href->{depth},
    'stylesheet' => $href->{stylesheet},
    'score' => $href->{score},
    'species'    => $self->{'proxiable'}->species,
  } );

  my $key     = $href->{name};
  my @configs = @{$href->{enable}};
  foreach my $cname (@configs) {
    my $config = $self->{'configs'}->{$cname} || next;
    if ($cname eq 'geneview') {

      next;
    }
      
    $config->set( "managed_extdas_$key", "on",         'on',                                                                          1);
    $config->set( "managed_extdas_$key", "dep",        defined($href->{depth}) ? $href->{depth} : $self->{'defaults'}{'DEPTH'},       1);
    $config->set( "managed_extdas_$key", "group",      $href->{group} ? $href->{group} : $self->{'defaults'}{'GROUP'},                1);
    $config->set( "managed_extdas_$key", "str",        $href->{strand} ? $href->{strand} : $self->{'defaults'}{'STRAND'},             1);
    $config->set( "managed_extdas_$key", "stylesheet", $href->{stylesheet} ? $href->{stylesheet} : $self->{'defaults'}{'STYLESHEET'}, 1);
    $config->set( "managed_extdas_$key", "score", $href->{score} ? $href->{score} : $self->{'defaults'}{'SCORE'}, 1);
    $config->set( "managed_extdas_$key", "lflag",      $href->{labelflag} ? $href->{labelflag} : $self->{'defaults'}{'LABELFLAG'},    1);
    $config->set( "managed_extdas_$key", "manager",    'das',                                                                         1);
    $config->set( "managed_extdas_$key", "col",        $href->{col} || $href->{color} ,                                               1);
    $config->set( "managed_extdas_$key", "enable",     $href->{enable} ,                                                              1);
    $config->set( "managed_extdas_$key", "mapping",    $href->{mapping} ,                                                             1);
#    $config->set( "managed_extdas_$key", "help",       $href->{help} || '',                                                           1);
    $config->set( "managed_extdas_$key", "linktext",   $href->{linktext} || '',                                                       1);
    $config->set( "managed_extdas_$key", "linkurl",    $href->{linkurl} || '',                                                        1);
##3 we need to store the configuration...
    $config->save;
  }

      $self->save_sources();
}

sub amend_source {
  my( $self, $hashref ) = @_;
  my $key = $hashref->{name} || "$hashref->{'URL'}/das/$hashref->{'dsn'}";
     $key =~ s/http:\/\///i;
     $key =~ s/\W/-/g;
  $self->{'data'}->{ $key } = $hashref;
  return $key;
}

sub delete_das_source {
  my( $self, $key ) = @_;
  delete $self->{'data'}{$key};
  foreach my $config ( values %{$self->{'configs'}}) {
    $config->set( "managed_extdas_$key", "on", "off" , 1);
    $config->save;
  }
  $self->save_sources( );
}

sub get_sources {
  my $self = shift;
  my $user_db = $self->{'proxiable'}->web_user_db;
  if( $user_db ) {
    eval {
      my $TEMP = $user_db->getConfigByName( $ENV{'ENSEMBL_FIRSTSESSION'}, 'externaldas' );
      $self->{'data'} = &Storable::thaw( $TEMP ) if defined $TEMP;
    };
    if ($@){
      warn "Error thawing ExternalDAS data: $@";
    }
  }
  return;
}

sub save_sources {
  my $self = shift;
  my $user_db = $self->{'proxiable'}->web_user_db;
  $user_db->setConfigByName( undef, $ENV{'ENSEMBL_FIRSTSESSION'}, 'externaldas', Storable::nfreeze($self->{'data'}) ) if $user_db;
}

1;