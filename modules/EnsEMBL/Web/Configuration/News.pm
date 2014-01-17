package EnsEMBL::Web::Configuration::News;

use strict;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Configuration;

our @ISA = qw( EnsEMBL::Web::Configuration );

#-----------------------------------------------------------------------

## Function to configure newsview

## This is a two-step view giving the user access to previous
## news items, by species, release, topic, etc.

sub newsview {
  my $self   = shift;
warn "Parameter ".$self->{object}->param('error');
  if (my $panel = $self->new_panel ('Image',
        'code'    => "info$self->{flag}",
        'object'  => $self->{object}) 
    ) {
    # this is a two-step view, so we need 2 separate sections
    if ($self->{object}->param('error') eq 'not_present') {
        $panel->{'caption'} = 'Not Present';
        $panel->add_components(qw(
                no_data     EnsEMBL::Web::Component::News::no_data
            ));
    }
    elsif ($self->{'object'}->param('submit') || $self->{'object'}->param('rel')) {
        # Step 2 - user has chosen a data range
        $panel->add_components(qw(show_news EnsEMBL::Web::Component::News::show_news));
    }
    else {
        # Step 1 - initial page display
        $panel->{'caption'} = 'Select News to View';
        $panel->add_components(qw(select_news EnsEMBL::Web::Component::News::select_news));
        $panel->add_form( $self->{page}, qw(select_news  EnsEMBL::Web::Component::News::select_news_form) );
    }
    $self->{page}->content->add_panel($panel);
  }
}

#-----------------------------------------------------------------------

sub context_menu {
    my $self = shift;
    my $species  = $self->{object}->species;
    my $flag     = "";
    $self->{page}->menu->add_block( $flag, 'bulleted', "News Archive" );

    $self->{page}->menu->add_entry( $flag, 'text' => "Select news to view",
                                  'href' => "/$species/newsview" );
}

#-----------------------------------------------------------------------

## Function to configure newsdb view

## This is a "wizard" view that steps the user through a series of forms
## in order to add and edit news items

sub newsdbview {
    my $self   = shift;

    if (my $panel = $self->new_panel ('Image',
        'code'    => "info$self->{flag}",
        'object'  => $self->{object}) 
    ) {
        if ($self->{object}->param('submit') eq 'Preview') {
            $panel->{'caption'} = 'News Preview';    
            $panel->add_components(qw(
                preview_item     EnsEMBL::Web::Component::News::preview_item
            ));
            $self->add_form( $panel, qw(preview_item     EnsEMBL::Web::Component::News::preview_item_form) );
        }
        elsif ($self->{object}->param('submit') eq 'Edit') {
            $panel->{'caption'} = 'Edit this article';    
            $panel->add_components(qw(
                edit_item     EnsEMBL::Web::Component::News::edit_item
            ));
            $self->add_form( $panel, qw(edit_item     EnsEMBL::Web::Component::News::edit_item_form) );
        }
        elsif ($self->{object}->param('step2') && $self->{object}->param('action') ne 'add') { 
            $panel->{'caption'} = 'Edit a News article';    
            $panel->add_components(qw(
                select_item_only     EnsEMBL::Web::Component::News::select_item_only
            ));
            $self->add_form( $panel, qw(select_item  EnsEMBL::Web::Component::News::select_item_form) );
        }
        elsif ($self->{object}->param('release_id')) { 
            $panel->{'caption'} = 'Add a News article';    
            $panel->add_components(qw(
                add_item     EnsEMBL::Web::Component::News::add_item
            ));
            $self->add_form( $panel, qw(add_item     EnsEMBL::Web::Component::News::add_item_form) );
        }
        elsif ($self->{object}->param('submit') eq 'Add' || $self->{object}->param('action') eq 'add' ) { 
            $panel->{'caption'} = 'Add a News article';    
            $panel->add_components(qw(
                select_to_add     EnsEMBL::Web::Component::News::select_to_add
            ));
            $self->add_form( $panel, qw(select_release  EnsEMBL::Web::Component::News::select_release_form) );
        }
        else {
            $panel->{'caption'} = 'Update the News Database';    

            $panel->add_components(qw(
                select_to_edit     EnsEMBL::Web::Component::News::select_to_edit
            ));
            $self->add_form( $panel, qw(select_item     EnsEMBL::Web::Component::News::select_item_form) );
            $self->add_form( $panel, qw(select_release  EnsEMBL::Web::Component::News::select_release_form) );
        }
        $self->add_panel($panel);

    }
}

#---------------------------------------------------------------------------

sub editor_menu {
    my $self = shift;

    my $flag     = "";
    $self->{page}->menu->add_block( $flag, 'bulleted', "Update News Database" );

    $self->{page}->menu->add_entry( $flag, 'text' => "Add News",
                                    'href' => "/default/newsdbview?action=add" );
    $self->{page}->menu->add_entry( $flag, 'text' => "Edit News",
                                    'href' => "/default/newsdbview?action=edit" );

}

1;