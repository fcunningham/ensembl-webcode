package EnsEMBL::Web::Form::FieldSet;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Root);

use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::Tools::RandomString;

sub new {
  my ($class, %option) = @_;
  
  my $name = $option{'name'} || EnsEMBL::Web::Tools::RandomString::random_string;
  
  my $self = {
    '_id'       => $option{'form'}."_$name",
    '_legend'   => $option{'legend'}  || '',
    '_stripes'  => $option{'stripes'} || 0,
    '_elements'       => {},
    '_element_order'  => [],
    '_set_id'   => 1,
    '_required' => 0,
    '_file'     => 0,
    '_extra'    => '',
    '_notes'    => '',
    '_class'    => '',
  };
  
  bless $self, $class;
  
  # Make adding of form elements as bulletproof as possible
  if ($option{'elements'} && ref($option{'elements'}) eq 'ARRAY') {
    foreach my $element (@{$option{'elements'}}) {
      if (ref($element) =~ /EnsEMBL::Web::Form::Element/) {
        $self->_add_element($element);
      } else {
        $self->add_element(%$element);
      }
    }    
  }
  
  return $self;
}

sub elements {
  my $self = shift;
  my $elements = [];
  foreach my $e (@{$self->{'_element_order'}}) {
    next unless $e;
    push @$elements, $self->{'_elements'}{$e} if $self->{'_elements'}{$e};
  }
  return $elements;
}

sub add_element {
  my( $self, %options ) = @_;
  my $module = "EnsEMBL::Web::Form::Element::$options{'type'}";
  
  if( $self->dynamic_use( $module ) ) {
    $self->_add_element( $module->new( 'form' => $self->{'_attributes'}{'id'}, %options ) );
  } else {
    warn "Unable to dynamically use module $module. Have you spelt the element type correctly?";
  }
}

sub _add_element {
  my( $self, $element ) = @_;
  if( $element->type eq 'File' ) { 
    $self->{'_file'} = 1;
  }
  if( $element->required eq 'yes' ) { 
    $self->{'_required'} = 1;
  }
  if (!$element->id) {
    $element->id =  $self->_next_id();
  }
  $self->{'_elements'}{$element->name} = $element;
  push @{$self->{'_element_order'}}, $element->name;
}

sub delete_element {
  my ($self, $name) = @_;
  return unless $name;
  delete $self->{'_elements'}{$name};
  ## Don't forget to remove it from the element order as well!
  my $keepers;
  foreach my $element (@{$self->{'_element_order'}}) {
    push @$keepers, $element unless $element eq $name;
  }
  $self->{'_element_order'} = $keepers;
}

sub modify_element {
### Modify an attribute of an EnsEMBL::Web::Form::Element object
  my ($self, $name, $attribute, $value) = @_;
  return unless ($name && $attribute);
  if ($name eq $attribute) {
    warn "!!! Renaming of elements not permitted! Remove this element and replace with a new one.";
    return;
  }
  my $element = $self->{'_elements'}{$name};
  if ($element && $element->can($attribute)) {
    $element->$attribute($value);
  }
}

sub legend {
  my $self = shift;
  $self->{'_legend'} = shift if @_;
  return $self->{'_legend'};
}

sub notes {
  my $self = shift;
  $self->{'_notes'} ||= [];
  push @{$self->{'_notes'}}, shift if @_;
  return $self->{'_notes'};
}

sub extra {
  my $self = shift;
  $self->{'_extra'} = shift if @_;
  return $self->{'_extra'};
}

sub class {
  my $self = shift;
  $self->{'_class'} = shift if @_;
  return $self->{'_class'};
}

sub _next_id {
  my $self = shift;
  return $self->{'_id'}.'_'.($self->{'_set_id'}++);
}

sub _render_element {
  my ($self, $element, $tint) = @_;
  my $output;
  if ($element->type eq 'Submit' || $element->type eq 'Button') {
    my $html = '<tr><td></td><td>';
    $html .= $element->render($tint);
    $html .= '</td></tr>';
    return $html;
  } else {
    return $element->render;
  }
}

sub render {
  my $self = shift;
  
  my $output = sprintf qq{<div class="%s"><fieldset%s>\n}, $self->class, $self->extra;
  $output .= sprintf "<h2>%s</h2>\n", encode_entities($self->legend) if $self->legend;
  
  if ($self->{'_required'}) {
    $self->add_element(
      'type'  => 'Information',
      'value' => 'Fields marked with <strong>*</strong> are required'
    )
  }
  
  foreach my $note (@{$self->notes||[]}) {
    my $class = exists $note->{'class'} && !defined $note->{'class'} ? '' : $note->{'class'} || 'notes';
    $class = qq{ class="$class"} if $class;
    
    $output .= qq{<div$class>};
    
    if ($note->{'heading'}) {
      $output .= "<h4>$note->{'heading'}</h4>";
    }
    
    if ($note->{'list'}) {
      $output .= '<ul>';
      $output .= "<li>$_</li>\n" for @{$note->{'list'}};
      $output .= '</ul>';
    } elsif ($note->{'text'}) {
      $output .= "<p>$note->{'text'}</p>";
    }
    
    $output .= "</div>\n";
  }
  
  $output .= qq{\n<table style="width:100%"><tbody>\n};
  
  my $hidden_output;
  my $i;
  
  foreach my $name (@{$self->{'_element_order'}}) {
    my $element = $self->{'_elements'}{$name};
    next unless $element;
    if ($element->type eq 'Hidden') {
      $hidden_output .= $self->_render_element($element);
    } else {
      if ($self->{'_stripes'}) {
        $element->bg = $i % 2 == 0 ? 'bg2' : 'bg1';
      }
      
      $output .= $self->_render_element($element);
    }
    
    $i++;
  }
  
  $output .= "\n</tbody></table>\n";
  $output .= $hidden_output;
  $output .= "\n</fieldset></div>\n";
  
  return $output;
}

1;
