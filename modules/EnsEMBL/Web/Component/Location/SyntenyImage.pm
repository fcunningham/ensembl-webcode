package EnsEMBL::Web::Component::Location::SyntenyImage;

### Module to replace part of the former SyntenyView, in this case displaying 
### an image of the syntenous chromosome regions 

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self    = shift;
  my $object  = $self->object;
  my $species = $object->species;
  my %synteny = $object->species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
  my $other   = $object->param('otherspecies') || $object->param('species') || $self->default_otherspecies;
  my $chr     = $object->seq_region_name;
  my %chr_1   = map { $_, 1 } @{$object->species_defs->ENSEMBL_CHROMOSOMES || []};
  my $chr_2   = scalar @{$object->species_defs->get_config($other, 'ENSEMBL_CHROMOSOMES')};
  
  unless ($synteny{$other}) {
    $object->problem('fatal', "Can't display synteny",  "There is no synteny data for these two species ($species and $other)");
    return undef;
  }
  
  unless ($chr_1{$chr} && $chr_2 > 0) {
    $object->problem('fatal', "Unable to display", "Synteny view only displays synteny between real chromosomes - not fragments");
    return undef;
  }

  my $ka         = $object->get_adaptor('get_KaryotypeBandAdaptor', 'core', $species);
  my $ka2        = $object->get_adaptor('get_KaryotypeBandAdaptor', 'core', $other);
  my $compara_db = $object->database('compara');
  my $raw_data   = $object->chromosome->get_all_compara_Syntenies($other, undef, $compara_db);   
  my $chr_length = $object->chromosome->length;
  
  my ($localgenes, $offset) = $object->get_synteny_local_genes;
  my $loc = (@$localgenes ? $localgenes->[0]->start + $object->seq_region_start : 1); # Jump loc to the location of the genes
  
  my $image_config = $object->get_imageconfig('Vsynteny');
  
  $image_config->{'other_species_installed'} = $synteny{$other};
  $image_config->container_width($chr_length);

  my $image = $self->new_vimage({
    chr           => $chr,
    ka_main       => $ka,
    sa_main       => $object->get_adaptor('get_SliceAdaptor'),
    ka_secondary  => $ka2,
    sa_secondary  => $object->get_adaptor('get_SliceAdaptor', 'core', $other),
    synteny       => $raw_data,
    other_species => $other,
    line          => $loc
  }, $image_config);

  $image->centred    = 1;  
  $image->imagemap   = 'yes';
  $image->image_type = 'syntenyview';
  $image->image_name = "$species-$chr-$other";
  $image->set_button('drag', 'title' => 'Click or drag to change region');

  my $chr_form = $self->chromosome_form('Vsynteny');

  $chr_form->add_element(
      type  => 'Hidden',
      name  => 'otherspecies',
      value => $self->hub->param('otherspecies') || $self->default_otherspecies,
  );

  my $html = sprintf('
<div>
  <div class="synteny_image">
    %s
  </div>
  <div class="synteny_forms">
    %s
    %s
  </div>
</div>
', $image->render, $self->species_form->render, $chr_form->render);

  return $html;
}

sub species_form {
  my $self             = shift;
  my $hub              = $self->hub;
  my $species_defs     = $hub->species_defs;
  my $url              = $hub->url({ otherspecies => undef }, 1);
  my $image_config     = $hub->get_imageconfig('Vsynteny');
  my $vwidth           = $image_config->image_height;
  my $form             = $self->new_form({ id => 'change_sp', action => $url->[0], method => 'get', class => 'autocenter check', style => $vwidth ? "width:${vwidth}px" : undef });
  my %synteny_hash     = $species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
  my %synteny          = %{$synteny_hash{$hub->species} || {}};
  my @sorted_by_common = sort { $a->{'common'} cmp $b->{'common'} } map {{ name => $_, common => $species_defs->get_config($_, 'SPECIES_COMMON_NAME') }} keys %synteny;
  my @values;

  foreach my $next (@sorted_by_common) {
    next if $next->{'name'} eq $hub->species;
    push @values, { caption => $next->{'common'}, value => $next->{'name'} };
  }

  $form->add_hidden({ name => $_, value => $url->[1]->{$_} }) for keys %{$url->[1]};
  $form->add_field({
    'label'       => 'Change Species',
    'inline'      => 1,
    'elements'    => [{
      'type'        => 'dropdown',
      'name'        => 'otherspecies',
      'values'      => \@values,
      'value'       => $hub->param('otherspecies') || $hub->param('species') || $self->default_otherspecies,
    }, {
      'type'        => 'submit',
      'value'       => 'Go'
    }]
  });

  return $form;
}


1;
