package EnsEMBL::Web::Form::Element::DropDown;

#--------------------------------------------------------------------
# Creates a form element for an option set, as either a select box
# or a set of radio buttons
# Takes an array of anonymous hashes, thus:
# my @values = (
#           {'name'=>'Option 1', 'value'=>'1'},
#           {'name'=>'Option 2', 'value'=>'2'},
#   );
# The 'name' element is displayed as a label or in the dropdown,
# whilst the 'value' element is passed as a form variable
#--------------------------------------------------------------------

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class  = shift;
  my %params = @_;
  my $self   = $class->SUPER::new(
    %params,
    'render_as' => $params{'select'} ? 'select' : 'radiobutton'
  );
  $self->{'on_change'} = $params{'on_change'};
  $self->{'firstline'} = $params{'firstline'};
  return $self;
}

sub firstline :lvalue { $_[0]->{'firstline'}; }

sub _validate() { return $_[0]->render_as eq 'select'; }

sub render {
  my $self = shift;
  if( $self->render_as eq 'select' ) {
    my $options = '';
    my $current_group;
    if( $self->firstline ) {
      $options .= sprintf qq(<option value="">%s</option>\n), CGI::escapeHTML( $self->firstline );
    }
    foreach my $V ( @{$self->values} ) {
      if( $V->{'group'} ne $current_group ) {
        if( $current_group ) {
          $options.="</optgroup>\n";
        }
        if( $V->{'group'}) {
          $options.= sprintf qq(<optgroup label="%s">\n), CGI::escapeHTML( $V->{'group'} );
        }
        $current_group = $V->{'group'};
      }
      $options .= sprintf( qq(<option value="%s"%s>%s</option>\n),
        $V->{'value'}, $self->value eq $V->{'value'} ? ' selected="selected"' : '', $V->{'name'}
      );
    }
    if( $current_group ) { $options.="</optgroup>\n"; }
    my $ON_CHANGE = $self->{'on_change'} eq 'submit' ? 
#       sprintf( "document.forms[%s].submit()", $self->form ) :
       sprintf( "document.%s.submit()", $self->{formname} ) :
       sprintf( "check('%s',this,%s)", $self->type, $self->required eq 'yes'?1:0 );  
    return sprintf( qq(%s<select name="%s" id="%s" class="normal" onChange="%s">\n%s</select>%s),
      $self->introduction,
      CGI::escapeHTML( $self->name ), CGI::escapeHTML( $self->id ),
      $ON_CHANGE,
      $options,
      $self->notes
    );
  } else {
    $output = '';
    my $K = 0;
    foreach my $V ( @{$self->values} ) {
      $output .= sprintf( qq(    <div class="%s"><input id="%s_%d" class="radio" type="radio" name="%s" value="%s" %s /><label for="%s_%d">%s</label></div>\n),
        $self->class||'radiocheck', CGI::escapeHTML($self->id), $K, CGI::escapeHTML($self->name), CGI::escapeHTML($V->{'value'}),
        $self->value eq $V->{'value'} ? ' checked="checked"' : '', CGI::escapeHTML($self->id), $K,
        CGI::escapeHTML($V->{'name'})
      );
      $K++;
    }
    return $self->introduction.$output.$self->notes;
  }
}

1;
