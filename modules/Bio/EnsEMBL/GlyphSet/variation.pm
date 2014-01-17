package Bio::EnsEMBL::GlyphSet::variation;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
use Data::Dumper;
use Bio::EnsEMBL::Variation::VariationFeature;


sub my_label { return "SNPs"; }

sub features {
  my ($self) = @_;
  my %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;
  &eprof_start('function-a');
  &eprof_start( 'get_all_vf' );
  my $vf_ref = $self->{'container'}->get_all_VariationFeatures();

  # Check for duplicate snps in DB
  #my %snps;
  #map { $snps{ $_->variation_name }++} @$vf_ref;
  #foreach (keys  %snps) {    warn "Name: $_, $snps{$_}\n";  }

  &eprof_end( 'get_all_vf' );
  &eprof_start( 'sort_vf' );  
  my @vari_features = 
     map  { $_->[1] }
     sort { $a->[0] <=> $b->[0] }
     map  { [ $ct{$_->get_consequence_type} * 1e9 + $_->start, $_ ] }
     grep { $_->map_weight < 4 } @$vf_ref;
  &eprof_end( 'sort_vf' );


  #  warn "@{[ map { $_->get_consequence_type } @vari_features ]}";
  if(@vari_features) {
    $self->{'config'}->{'variation_legend_features'}->{'variations'} 
        = { 'priority' => 1000, 'legend' => [] };
  }
  &eprof_end('function-a');
  return \@vari_features;
}

sub href {
  my $self = shift;
  my $f    = shift;
  my $view = shift || 'snpview';

  &eprof_start('href'); 
  my $start  = $self->slice2sr( $f->start, $f->end );
  my $id     = $f->variation_name;
  my $source = $f->source;
  my $region = $self->{'container'}->seq_region_name();
  &eprof_end('href');

  if ($view eq 'ldview' ){
    my $Config   = $self->{'config'};
    my $only_pop = $Config->{'_ld_population'};
    $start .= ";pop=$only_pop" if $only_pop;
  }
  return "/@{[$self->{container}{_config_file_name_}]}/$view?snp=$id;source=$source;c=$region:$start;w=20000";
}

sub image_label {
  my ($self, $f) = @_;
  &eprof_start( 'il' );  
  my $ambig_code = $f->ambig_code;
  my @T = $ambig_code eq '-' ? undef : ($ambig_code,'overlaid');
  &eprof_end( 'il' );
  return @T;
}

sub tag {
  my ($self, $f) = @_;
  &eprof_start( 'tag' );
  my $so_that_I_can_eprof_tag;
  if($f->start > $f->end ) {
    
    my $consequence_type = $f->get_consequence_type;
    $so_that_I_can_eprof_tag = ( { 'style' => 'insertion', 
	       'colour' => $self->{'colours'}{"$consequence_type"} } );
  }
  else {
     $so_that_I_can_eprof_tag = undef;
  }
  &eprof_end( 'tag' );
  return $so_that_I_can_eprof_tag;
}

sub colour {
  my ($self, $f) = @_;
  # Allowed values are: 
  #  'FRAMESHIFT_CODING',  'NON_SYNONYMOUS_CODING',  'SYNONYMOUS_CODING',
  #  '5PRIME_UTR','3PRIME_UTR','INTRONIC','UPSTREAM','DOWNSTREAM','INTERGENIC'
  &eprof_start( 'colour' );
  my $consequence_type = $f->get_consequence_type();
  unless($self->{'config'}->{'variation_types'}{$consequence_type}) {
    my %labels = (
         	  '_'                    => 'Other SNPs',
		  'INTRONIC'             => 'Intronic SNPs',
		  'UPSTREAM'             => 'Upstream',
		  'DOWNSTREAM'           => 'Downstream',
		  'SYNONYMOUS_CODING'    => 'Synonymous coding',
		  'NON_SYNONYMOUS_CODING'=> 'Non-synonymous coding',
		  'FRAMESHIFT_CODING'    => 'Frameshift coding SNP',
		  '5PRIME_UTR'           => '5\' UTR',
		  '3PRIME_UTR'           => '3\' UTR',
                  'UTR'                  => 'UTR',
		  'INTERGENIC'           => 'Intergenic SNPs',
                  'STOP_GAINED'          => 'Stop gained',
                  'STOP_LOST'            => 'Stop lost',
		 );
    push @{ $self->{'config'}->{'variation_legend_features'}->{'variations'}->{'legend'}},
     $labels{$consequence_type} => $self->{'colours'}{$consequence_type};
    $self->{'config'}->{'variation_types'}{$consequence_type} = 1;
  }
  &eprof_end( 'colour' );
  return $self->{'colours'}{$consequence_type},
    $self->{'colours'}{"label$consequence_type"}, 
      $f->start > $f->end ? 'invisible' : '';
}


sub zmenu {
  my ($self, $f ) = @_;
  &eprof_start('zmenu');
  my( $start, $end ) = $self->slice2sr( $f->start, $f->end );
  my $allele = $f->allele_string;
  my $pos =  $start;

  if($f->start > $f->end  ) {
    $pos = "between&nbsp;$start&nbsp;&amp;&nbsp;$end";
  }
  elsif($f->start < $f->end ) {
    $pos = "$start&nbsp;-&nbsp;$end";
  }

  my $status = join ", ", @{$f->get_all_validation_states};
  my %zmenu = ( 
 	       caption               => "SNP: " . ($f->variation_name),
 	       '01:SNP properties'   => $self->href( $f, 'snpview' ),
               ( $self->{'config'}->_is_available_artefact( 'database_tables ENSEMBL_VARIATION.pairwise_ld' ) ?
 	         ( '02:View in LDView'   => $self->href( $f, 'ldview' ) ) : ()
               ),
 	       "03:bp: $pos"         => '',
 	       "04:status: ".($status || '-') => '',
 	       "05:SNP type: ".($f->var_class || '-') => '',
 	       "07:ambiguity code: ".$f->ambig_code => '',
 	       "08:alleles: ".$f->allele_string => '',
	      );

 # foreach my $db (@{  $variation->get_all_synonym_sources }) {
  #  if( $db eq 'TSC-CSHL' || $db eq 'HGVBASE' || $db eq 'dbSNP' || $db eq 'WI' ) {
  #  }
  #}
  $zmenu{"16:dbSNP: ".$f->variation_name} =
    $self->ID_URL("dbSNP", $f->variation_name) if $f->source eq 'dbSNP';

  my $consequence_type = $f->get_consequence_type;
  $zmenu{"57:Type: $consequence_type"} = "" unless $consequence_type eq '';  
  eprof_end( 'zmenu' );
  return \%zmenu;
}
1;