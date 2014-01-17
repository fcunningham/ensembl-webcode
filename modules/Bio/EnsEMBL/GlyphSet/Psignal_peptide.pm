package Bio::EnsEMBL::GlyphSet::Psignal_peptide;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
	'text'      => 'Signal peptide',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}


sub _init {
    my ($self) = @_;
    my %hash;
    
    my $y       = 0;
    my $h       = 4;
    my $protein = $self->{'container'};
    my $Config  = $self->{'config'};  

    $protein->dbID || return; # Non-database translation

    my @sigp_feat = @{$protein->get_all_ProteinFeatures('Signalp')};
    foreach my $feat(@sigp_feat) {
	push(@{$hash{$feat->hseqname}},$feat);
    }
    
    my $caption = "signal_peptide";
    foreach my $key (keys %hash) {
	my @row = @{$hash{$key}};
	my $desc = $row[0]->idesc();
	my $Composite = new Sanger::Graphics::Glyph::Composite({
	    
	});
	
	my $colour = $Config->get('Psignal_peptide','col');
	
	foreach my $pf (@row) {
	    my $x  = $pf->start();
	    my $w  = $pf->end - $x;
	    my $id = $pf->hseqname();
	    
	    my $rect = new Sanger::Graphics::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'id'       => $id,
		'colour'   => $colour,
		});
	    $Composite->push($rect);
	}
	
	$self->push($Composite);
    }
}
1;