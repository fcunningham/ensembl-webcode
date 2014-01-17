#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::Renderer;
use Sanger::Graphics::Glyph::Poly;
use strict;

sub new {
  my ($class, $config, $extra_spacing, $glyphsets_ref) = @_;
  
  my $self = {
	      'glyphsets' => $glyphsets_ref,
	      'canvas'    => undef,
	      'colourmap' => $config->colourmap(),
	      'config'    => $config,
	      'extra_spacing' => $extra_spacing,
	      'spacing'   => $config->get('_settings','spacing')||2,
	      'margin'    => $config->get('_settings','margin')||5,
	     };
  
  bless($self, $class);
  
  $self->render();
  
  return $self;
}

sub config {
  my ($self, $config) = @_;
  $self->{'config'}   = $config if($config);
  return $self->{'config'};
}

sub render {
  my ($self) = @_;
  
  my $config = $self->{'config'};
  
  #########
  # now set all our labels up with scaled negative coords
  # and while we're looping, tot up the image height
  #
  my $spacing   = $self->{'spacing'};
  my $im_height = $self->{'margin'} * 2 - $spacing;
  
  for my $glyphset (@{$self->{'glyphsets'}}) {
    next if (scalar @{$glyphset->{'glyphs'}} == 0 || 
             scalar @{$glyphset->{'glyphs'}} == 1 && ref($glyphset->{'glyphs'}[0])=~/Diagnostic/ );
    
    my $fntheight = (defined $glyphset->label())?$config->texthelper->height($glyphset->label->font()):0;
    my $gstheight = $glyphset->height();
    
    if($gstheight > $fntheight) {
      $im_height += $gstheight + $spacing;
    } else {
      $im_height += $fntheight + $spacing;
    }
  }
  $im_height += $self->{'extra_spacing'};
  $config->image_height( $im_height );
  my $im_width = $config->image_width();
  
  #########
  # create a fresh canvas
  #
  if($self->can('init_canvas')) {
    $self->init_canvas($config, $im_width, $im_height );
  }
  
  my %tags;
  my %layers = ();
  for my $glyphset (@{$self->{'glyphsets'}}) {
    foreach( keys %{$glyphset->{'tags'}}) {
      if($tags{$_}) {
	# my @points = ( @{$tags{$_}}, @{$glyphset->{'tags'}{$_}} );
        my $COL   = undef;
        my $FILL  = undef;
        my $Z     = undef;
	my @points = map { 
          $COL  = defined($COL)  ? $COL  : $_->{'col'};
          $FILL = defined($FILL) ? $FILL : ($_->{'style'} && $_->{'style'} eq 'fill'); 
          $Z    = defined($Z)    ? $Z    : $_->{'z'};
	  (
	   $_->{'glyph'}->pixelx + $_->{'x'} * $_->{'glyph'}->pixelwidth,
	   $_->{'glyph'}->pixely + $_->{'y'} * $_->{'glyph'}->pixelheight
	  ) } (@{$tags{$_}}, @{$glyphset->{'tags'}{$_}});
	my $first = $glyphset->{'tags'}{$_}[0];
        my $PAR = { 
		   'pixelpoints'  => [ @points ],
		   'bordercolour' => $COL,
		   'absolutex'    => 1,
		   'absolutey'    => 1,
		  };
        $PAR->{'colour'} = $COL if($FILL);
	my $glyph = Sanger::Graphics::Glyph::Poly->new($PAR);
	push @{$layers{defined $Z ? $Z : -1 }}, $glyph;
	delete $tags{$_};
      } else {
	$tags{$_} = $glyphset->{'tags'}{$_}
      }       
    }
    foreach( @{$glyphset->{'glyphs'}} ) {
      push @{$layers{$_->{'z'}||0}}, $_;
    }
  }
  
  for my $layer ( sort { $a<=>$b } keys %layers ) {
    #########
    # loop through everything and draw it
    #
    for ( @{$layers{$layer}} ) {
      my $method = $self->method($_);
      if($self->can($method)) {
	$self->$method($_);
      } else {
	print STDERR qq(Sanger::Graphics::Renderer::render: Do not know how to $method\n);
      }
    }
  }
  
  
  #########
  # the last thing we do in the render process is add a frame
  # so that it appears on the top of everything else...
  
  $self->add_canvas_frame($config, $im_width, $im_height);
}

sub canvas {
  my ($self, $canvas) = @_;
  $self->{'canvas'} = $canvas if(defined $canvas);
  return $self->{'canvas'};
}

sub method {
  my ($self, $glyph) = @_;
  
  my ($suffix) = ref($glyph) =~ /.*::(.*)/;
  return qq(render_$suffix);
}

sub render_Diagnostic { 1; }
sub render_Composite {
  my ($self, $glyph) = @_;
  
  for my $subglyph (@{$glyph->{'composite'}}) {
    my $method = $self->method($subglyph);
    if($self->can($method)) {
      $self->$method($subglyph);
    } else {
      print STDERR qq(Sanger::Graphics::Renderer::render_Composite: Do not know how to $method\n);
    }
  }
}

#########
# empty stub for Blank spacer objects with no rendering at all
#
sub render_Space {
}

#########
# placeholder for renderers which can't import sprites
#
sub render_Sprite {
  my $self = shift;
  return $self->render_Rect(@_);
}

1;