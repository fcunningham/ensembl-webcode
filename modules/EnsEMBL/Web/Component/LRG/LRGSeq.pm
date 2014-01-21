=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::LRG::LRGSeq;

use strict;

use base qw(EnsEMBL::Web::Component::Gene::GeneSeq);

sub _init {
  my $self = shift;
  my $hub  = $self->hub;
  
  $self->SUPER::_init;
  $self->{'subslice_length'} = $hub->param('force') || 10000 * ($hub->param('display_width') || 60);
}

sub content_rtf {
  my $self = shift;
  return $self->export_sequence($self->initialize($self->object->Obj));
}

1;