package EnsEMBL::Web::Component::Search::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Search);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML::HomeSearch;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;

  my $html;
  my $search = EnsEMBL::Web::Document::HTML::HomeSearch->new();
  $html .= $search->render;

=pod
  my $exa_obj = $self->object->Obj;
  my $renderer = new ExaLead::Renderer::HTML( $exa_obj );
  my $html = $renderer->render_form .
    $renderer->render_summary .
    $renderer->render_navigation .
    $renderer->render_hits;
=cut
  return $html;
}

1;

