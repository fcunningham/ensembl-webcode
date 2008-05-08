package EnsEMBL::Web::Controller::Command::User::ResetFavourites;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data::SpeciesList;
use EnsEMBL::Web::Document::HTML::SpeciesList;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Redirect');
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::DataUser');
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->render_page;
  }
}

sub render_page {
  my $self = shift;
  my $user = $self->filters->user;
  warn "RENDERING PAGE for RESET";
  foreach my $list (@{ $user->specieslists }) {
    warn "LIST: " . $list->id;
    $list->destroy;
  }
  $self->filters->redirect('/index.html');
}

}

1;
