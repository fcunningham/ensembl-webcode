=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::UserData::SelectFile;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Utils::Feedback qw(add_userdata_message);

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Select File to Upload';
}

sub content {
  my $self            = shift;
  my $hub             = $self->hub;
  my $sd              = $hub->species_defs;
  my $sitename        = $sd->ENSEMBL_SITETYPE;
  my $current_species = $hub->data_species;
  my $max_upload_size = abs($sd->CGI_POST_MAX / 1048576).'MB'; # Should default to 5.0MB :)
  
  ## default JS validation is skipped as this form goes through a customised validation
  my $form = $self->modal_form('select', 
                                $hub->url({'type' => 'UserData', 'action' => 'CheckFile'}), 
                                { 
                                  'skip_validation' => 1, 
                                  'class' => 'check',   
                                  'no_button' => 1
                                },
                              ); 
  my $fieldset = $form->add_fieldset({'no_required_notes' => 1});

  $fieldset->add_field({'type' => 'String', 'name' => 'name', 'label' => 'Name for this data (optional)'});

  ## Create a data structure for species, with display labels and their current assemblies
  my @species = sort {$a->{'caption'} cmp $b->{'caption'}} map({'value' => $_, 'caption' => $sd->species_label($_, 1), 'assembly' => $sd->get_config($_, 'ASSEMBLY_VERSION')}, $sd->valid_species);

  ## Create HTML for showing/hiding assembly names to work with JS
  my $assembly_names = join '', map { sprintf '<span class="_stt_%s%s">%s</span>', $_->{'value'}, $_->{'value'} eq $current_species ? '' : ' hidden', delete $_->{'assembly'} } @species;

  $fieldset->add_field({
      'type'        => 'dropdown',
      'name'        => 'species',
      'label'       => 'Species',
      'values'      => \@species,
      'value'       => $current_species,
      'class'       => '_stt'
  });

  ## Are mappings available?
  ## FIXME - reinstate auto-mapping option when we have a solution!
  ## TODO - once fixed, the assembly name toggling (wrt species selected) will need redoing - hr5
  my $mappings; # = $sd->ASSEMBLY_MAPPINGS;
  my $current_assembly = $sd->get_config($current_species, 'ASSEMBLY_VERSION');
  if ($mappings && ref($mappings) eq 'ARRAY') {
    my @values = {'name' => $current_assembly, 'value' => $current_assembly};
    foreach my $string (reverse sort @$mappings) { 
      my @A = split('#|:', $string);
      my $assembly = $A[3];
      push @values, {'name' => $assembly, 'value' => $assembly};
    }
    $form->add_element(
      'type'        => 'DropDown',
      'name'        => 'assembly',
      'label'       => "Assembly",
      'values'      => \@values,
      'value'       => $current_assembly,
      'select'      => 'select',
    );
    $form->add_element(
      'type'        => 'Information',
      'value'       => 'Please note: if your data is not on the current assembly, the coordinates will be converted',
    );
  }
  else {
    $fieldset->add_field({
      'type'        => 'noedit',
      'label'       => 'Assembly',
      'name'        => 'assembly_name',
      'value'       => $assembly_names,
      'no_input'    => 1,
      'is_html'     => 1
    });
  }

  $fieldset->add_field({
      'type'        => 'Text',
      'name'        => 'text',
      'label'       => 'Paste data',
  });

  $fieldset->add_field({
      'type'        => 'File',
      'name'        => 'file',
      'label'       => 'Upload file',
  });

  $fieldset->add_field({
      'type'        => 'String',
      'name'        => 'url',
      'label'       => 'Provide URL',
  });

  $self->add_hidden_format_dropdown($form);

  $fieldset->add_button({
      'name'        => 'submit_button',
      'value'       => 'Next',
  });

  return sprintf '<input type="hidden" class="subpanel_type" value="UserData" /><h2>Add a custom track</h2>%s', $form->render;
}

1;
