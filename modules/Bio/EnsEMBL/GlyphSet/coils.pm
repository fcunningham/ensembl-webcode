package Bio::EnsEMBL::GlyphSet::coils;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => 'coils',
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($this, $protein, $Config) = @_;
    my %hash;
    my $caption = "coils";

    my $y          = 0;
    my $h          = 4;
    my $highlights = $this->highlights();

    my $protein = $this->{'container'};
    my $Config = $this->{'config'}; 
    
foreach my $feat ($protein->each_Protein_feature()) {
              
    print STDERR $feat->feature2->seqname, "\n";

       if ($feat->feature2->seqname eq "coils") {
	   push(@{$hash{$feat->feature2->seqname}},$feat);
       }
    }
    
    foreach my $key (keys %hash) {
	
	
	my @row = @{$hash{$key}};
       
     
	my $desc = $row[0]->idesc();

	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    'id'    => $key,
	    'zmenu' => {
		'caption'  => $key,
		$desc => ''
	    },
	});
	   
	my $colour = $Config->get($Config->script(), 'coils','col');
#To be changed
	
	#$colour    = $Config->get('transview','transcript','hi') if(defined $highlights && $highlights =~ /\|$vgid\|/);


	foreach my $pf (@row) {
	    my $x = $pf->feature1->start();
	    my $w = $pf->feature1->end - $x;
	    my $id = $pf->feature2->seqname();
	    
	    my $rect = new Bio::EnsEMBL::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'id'       => $id,
		'colour'   => $colour,
	    });
	    
	    
	    $Composite->push($rect) if(defined $rect);
	    
	}

#	push @{$this->{'glyphs'}}, $Composite;
	$this->push($Composite);
	$y = $y + 8;
    }
        
   
}
1;




















