package Bio::EnsEMBL::GlyphSet::Pprints;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;

use  Sanger::Graphics::Bump;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
	'text'      => 'Prints',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my %hash;
    my $protein       = $self->{'container'};
    my @bitmap;
    my $Config        = $self->{'config'};
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($protein->length * $pix_per_bp);
    my $y             = 0;
    my $h             = 4;
    my $colour        = $Config->get('Pprints','col');
    my $caption       = "Prints";
    my $font          = "Small";
    my ($fontwidth,
	$fontheight)  = $Config->texthelper->px2bp($font);

    $protein->dbID || return; # Non-database translation

    my @pr_feat = @{$protein->get_all_ProteinFeatures('Prints')};
    foreach my $feat(@pr_feat) {
	push(@{$hash{$feat->hseqname}},$feat);
    }
    
    foreach my $key (keys %hash) {
	my @row = @{$hash{$key}};
	my $desc = $row[0]->idesc();
		
	my $Composite = new Sanger::Graphics::Glyph::Composite({
	    'x'     => $row[0]->start(),
	    'y'     => $y,
	    'href'	   => $self->ID_URL( 'PRINTS', $key ),
		'zmenu' => {
		'caption'  	=> "Prints Domain",
		$key 		=> $self->ID_URL( 'PRINTS', $key  )
	    },
	});

	my $prsave;
	my ($minx, $maxx);
		
	foreach my $pr (@row) {
	    my $x  = $pr->start();
	    $minx  = $x if ($x < $minx || !defined($minx));
	    my $w  = $pr->end() - $x;
	    $maxx  = $pr->end() if ($pr->end() > $maxx || !defined($maxx));
	    my $id = $pr->hseqname();
	    
	    my $rect = new Sanger::Graphics::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'colour'   => $colour,
	    });
	    $Composite->push($rect);
	    $prsave = $pr;
	}

	#########
	# add a domain linker
	#
	my $rect = new Sanger::Graphics::Glyph::Rect({
	    'x'        => $minx,
	    'y'        => $y + 2,
	    'width'    => $maxx - $minx,
	    'height'   => 0,
	    'colour'   => $colour,
	    'absolutey' => 1,
	});
	$Composite->push($rect);
	
	#########
	# add a label
	#
	$desc = $prsave->idesc() || $key;
	my $text = new Sanger::Graphics::Glyph::Text({
	    'font'   => $font,
	    'text'   => $desc,
	    'x'      => $row[0]->start(),
	    'y'      => $h + 1,
	    'height' => $fontheight,
	    'width'  => $fontwidth * length($desc),
	    'colour' => $colour,
	});
	$Composite->push($text);

	if ($Config->get('Pprints', 'dep') > 0){ # we bump
            my $bump_start = int($Composite->x() * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);
	    
            my $bump_end = $bump_start + int($Composite->width()*$pix_per_bp);
            if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};
            my $row = & Sanger::Graphics::Bump::bump_row(
				      $bump_start,
				      $bump_end,
				      $bitmap_length,
				      \@bitmap
				      );
            $Composite->y($Composite->y() + (1.5 * $row * ($h + $fontheight)));
        }
	
	$self->push($Composite);
    }
}

1;