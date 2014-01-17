package Bio::EnsEMBL::GlyphSet::snp_fake;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Rect;
use Bio::EnsEMBL::GlyphSet;
  
@Bio::EnsEMBL::GlyphSet::snp_fake::ISA = qw(Bio::EnsEMBL::GlyphSet);
sub _init {
  my ($self) = @_;

  my $Config        = $self->{'config'};
  my $container     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'};
  my $target_gene   = $Config->{'geneid'};
    
  my $h             = 24;
    
  my @bitmap        = undef;
  my $colours       = $Config->get('snp_fake','colours' );

  my $pix_per_bp    = $Config->transform->{'scalex'};

  my $strand  = $self->strand();
  my $length  = $container->length;
    
  my %exons = ();
  
  my ($w,$th) = $Config->texthelper()->px2bp($Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'});
  my @snps = @{$Config->{'snps'}};
  my $tag = $Config->get( 'snp_fake', 'tag' );
  my $tag2 = $tag + ($strand == -1 ? 1 : 0);
  my $start = $container->start();
  foreach my $snp_ref ( @snps ) { 
    my $snp = $snp_ref->[2];
    my( $S,$E ) = ($snp_ref->[0], $snp_ref->[1] );
    $S = 1 if $S < 1;
    $E = $length if $E > $length;
    my $tag_root = $snp->dbID;
    my $type = $snp->get_consequence_type();
    my $colour = $colours->{$type};
    my $label = $snp->allele_string;
    my $bp_textwidth = $w * length("$label");
    if( $bp_textwidth < $E-$S+1 ) {
      my $textglyph = new Sanger::Graphics::Glyph::Text({
                'x'          => ( $E + $S - 1 - $bp_textwidth)/2,
                'y'          => ($h-$th)/2,
                'width'      => $bp_textwidth,
                'height'     => $th,
                'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
                'colour'     => 'black',
                'text'       => $label,
                'absolutey'  => 1,
      });
      $self->push( $textglyph );
    } elsif( ($w < $E-$S+1) && $label =~ /^(-|\w)\/(-|\w)$/ ) {
      my($X,$Y) = ($1,$2);
      my $textglyph = new Sanger::Graphics::Glyph::Text({
                'x'          => ( $E + $S - 1 - $w)/2,
                'y'          => ($h-2*$th-2)/2,
                'width'      => $w,
                'height'     => $th,
                'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
                'colour'     => 'black',
                'text'       => $X,
                'absolutey'  => 1,
      });
      $self->push( $textglyph );
      my $textglyph = new Sanger::Graphics::Glyph::Text({
                'x'          => ( $E + $S - 1 - $w)/2,
                'y'          => ($h+2)/2,
                'width'      => $w,
                'height'     => $th,
                'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
                'colour'     => 'black',
                'text'       => $Y,
                'absolutey'  => 1,
      });
      $self->push( $textglyph );
    }
    my $tglyph = new Sanger::Graphics::Glyph::Rect({
      'x' => $S-1,
      'y' => 0,
      'bordercolour' => $colour,
      'absolutey' => 1,
      'href' => $self->href($snp),
      'zmenu' => $self->zmenu($snp),
      'height' => $h,
      'width'  => $E-$S+1,
    });
    $self->join_tag( $tglyph, "X:$tag_root=$tag2", .5, 0, $colour,'',-3 );
    $self->push( $tglyph );
  }
  my %labels = (
         '_coding' => 'Coding SNPs',
         '_utr'    => 'UTR SNPs',
         '_intron' => 'Intronic SNPs',
         '_local'  => 'Flanking SNPs',
         '_'       => 'Other SNPs' );
 # $self->{'config'}->{'snp_legend_features'} = {};
 # $self->{'config'}->{'snp_legend_features'}->{'snps'} = {}
  $self->{'config'}->{'snp_legend_features'}->{'snps'}->{'legend'} = [
    map { $labels{"$_"} => $colours->{"$_"} } keys %labels
  ];
}

sub zmenu {
    my ($self, $f ) = @_;
    my $start = $f->start() + $self->{'container'}->start() - 1;
    my $end   = $f->end() + $self->{'container'}->start() - 1;

    my $allele = $f->allele_string;
    my $pos =  $start;
    if($f->{'range_type'} eq 'between' ) {
       $pos = "between&nbsp;$start&nbsp;&amp;&nbsp;$end";
    } elsif($f->{'range_type'} ne 'exact' ) {
       $pos = "$start&nbsp;-&nbsp;$end";
   }
    my %zmenu = ( 
        'caption'           => "SNP: ".$f->variation_name(),
        '01:SNP properties' => $self->href( $f ),
        "02:bp: $pos" => '',
        "03:class: ".$f->var_class() => '',
        "03:status: ".join(', ', @{$f->get_all_validation_states||[]} ) => '',
        "06:mapweight: ".$f->map_weight => '',
        "07:ambiguity code: ".$f->ambig_code => '',
        "08:alleles: ".(length($allele)<16 ? $allele : substr($allele,0,14).'..') => ''
   );

    my %links;
    
    my $source = $f->source; 
    my $type = $f->get_consequence_type;
    $zmenu{"57:Type: $type"} = "" unless $type eq '';  
    return \%zmenu;
}

sub href {
    my ($self, $f ) = @_;
    my $start = $self->{'container'}->start()+$f->start;
    my $snp_id = $f->variation_name;
    my $source = $f->source;
    my $seq_region_name = $self->{'container'}->seq_region_name();

    return "/@{[$self->{container}{_config_file_name_}]}/snpview?snp=$snp_id;source=$source;chr=$seq_region_name;vc_start=$start";
}

1;