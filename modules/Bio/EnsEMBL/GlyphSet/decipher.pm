#########
# Author: rmp
# Maintainer: rmp
# Created: 2004-04-26
# Last Modified: 2004-04-26
#
# DECIPHER Project sub-microscopic alterations
# Homepage: http://decipher.sanger.ac.uk/
#
package Bio::EnsEMBL::GlyphSet::decipher;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::SeqFeature;
use EnsWeb;
use Bio::Das;

@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { "DECIPHER"; }

sub features {
  return unless ref(EnsWeb::species_defs->ENSEMBL_TRACK_DAS_SOURCES) eq 'HASH';

  my $self         = shift;
  my $slice        = $self->{'container'};
  my $start        = $slice->start();
  my $end          = $slice->end();
  my $chr          = $slice->seq_region_name();
  my $offset       = -$start+1;
  my $species_defs = &EnsWeb::species_defs();
  my $dbname       = EnsWeb::species_defs->ENSEMBL_TRACK_DAS_SOURCES->{"das_DECIPHER"};
  my $dsn          = $dbname->{'url'} . "/" . $dbname->{'dsn'};
  $dsn             = "http://$dsn" unless ($dsn =~ /^https?:\/\//i);
  my @features     = ();
  my $das          = Bio::Das->new(20);
  $das->proxy($species_defs->ENSEMBL_DAS_PROXY);

  $das->features(
		 -segment  => "$chr:$start,$end",
		 -dsn      => $dsn,
		 -callback => sub {
		   my $f = shift;
		   return if($f->isa("Bio::Das::Segment"));
		   push @features, $f;
		 },
		);

  my $res   = [];
  @features = sort { $a->orientation() cmp $b->orientation() || $a->group() cmp $b->group() } @features;

  while(@features) {
    my @parts  = $features[0..1];
    my ($hard) = grep { $_->{'type'} !~ /fuzzy/ } @features;
    my ($soft) = grep { $_->{'type'} =~ /fuzzy/ } @features;
    shift @features;
    shift @features;

    my $s = Bio::EnsEMBL::SeqFeature->new(
					  -start   => $hard->start()+$offset,
					  -end     => $hard->end()+$offset,
					  -strand  => -1,
					  -seqname => $hard->label(),
					 );
    $s->{'decipher_softstart'} = $soft->start()+$offset;
    $s->{'decipher_softend'}   = $soft->end()+$offset;
    $s->{'decipher_note'}      = $soft->note();
    $s->{'decipher_link'}      = $soft->link();
    $s->{'decipher_strand'}    = ($soft->orientation() eq "-")?-1:1;

    push @{$res}, $s;
  }
  return $res;
}

sub colour {
  my ($self, $f) = @_;
  ($f->{'decipher_strand'} < 0)?"red":"green";
}

sub href  { return undef; }
sub zmenu {
  my ($self, $f) = @_;
  return {
	  'caption' => "DECIPHER:" . $f->seqname(),
	  '01:<b>Phenotype:</b>' . $f->{'decipher_note'} => undef,
	  '02:Report' => $f->{'decipher_link'},
	 };
}

sub image_label {
  my ($self, $f) = @_;
  return ($f->seqname(),'overlaid');
}

sub tag {
  my ($self, $f) = @_;
  return ({
	   'start'  => $f->{'decipher_softstart'},
	   'end'    => $f->start(),
	   'style'  => 'line',
	   'colour' => $self->colour($f),
	  },
	  {
	   'start'  => $f->end(),
	   'end'    => $f->{'decipher_softend'},
	   'style'  => 'line',
	   'colour' => $self->colour($f),
	  });
}

1;
