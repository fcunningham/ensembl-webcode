package EnsEMBL::Web::Component::SNP;

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Fiona Cunningham <webmaster@sanger.ac.uk>

=cut

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";
use POSIX qw(floor ceil);
use CGI qw(escapeHTML);
#use Data::Dumper;
#$Data::Dumper::Indent = 3;

# Notes:
# Variation object: has all the data (flanks, alleles) but no position
# VariationFeature: has position (but also short cut calls to allele etc.) 
#                   for contigview

# TEST SNPs  gives and ERROR 1065427
# 3858116 has TSC sources, 557122 hapmap (works), 2259958 (senza-hit), 625 multi-hit, lots of LD 2733052, 2422821, 12345
# Problem snp  	1800704 has no upstream, downstream seq
# Tagged snps: rs8, rs46,  rs1467672
# slow one: 431235


# General info table #########################################################

=head2 name

 Arg1        : panel
 Arg2        : data object
 Example     : $panel1->add_rows(qw(name   EnsEMBL::Web::Component::SNP::name) );
 Description : adds a label and the variation name, source to the panel
 Return type : 1

=cut

sub name {
  my($panel, $object) = @_;
  my $label  = 'SNP';
  my $name   = $object->name;
  my $source = $object->source;
  $name      = $object->get_ExtURL_link($name, 'SNP', $name) if $source eq 'dbSNP';
  my $html  = "<b>$name</b> ($source". $object->source_version.")";
  $panel->add_row( $label, $html );
  return 1;
}


=head2 synonyms

 Arg1        : panel
 Arg2        : data object
 Example     : $panel1->add_rows(qw(synonyms   EnsEMBL::Web::Component::SNP::synonyms) );
 Description : adds a label and the variation synonyms to the panel
 Return type : 1

=cut

sub synonyms {
  my($panel, $object) = @_;
  my $label = 'Synonyms';
  my %synonyms = %{$object->dblinks};
  my $info;

  foreach my $db (keys %synonyms) {
    my @ids =  @{ $synonyms{$db} } ;
    my @urls;
    my $display_db;

    if ($object->source eq 'dbSNP') {
      if ($db =~ /dbsnp/i) {
 	$display_db = "dbSNP";
 	#  The synonyms in the db are ssids
 	#@urls  = map {  $object->get_ExtURL('SNP', $_) ) } @ids;
 	@urls  = map { $object->get_ExtURL_link($_, 'DBSNPSS', $_) } @ids;
      }
    } 
    elsif ($object->source eq 'Glovar') {
      if ($db =~ /dbsnp rs/i) {
 	$display_db = "dbSNP rs";
 	@urls  = map {  $object->get_ExtURL_link( $_, 'SNP', $_)  } @ids;
      }
      elsif ($db =~ /dbsnp ss/i) {
 	$display_db = "dbSNP ss";
 	@urls  = map {  $object->get_ExtURL_link( $_, 'DBSNPSS', $_ ) } @ids;
      }
    }				# end elseif glover

    else {
      $display_db = "Other";
      @urls = @ids;
    }

    if ($db =~ /hgvbase/i) {
      $display_db = "HGVbase";
      @urls  = map {  $object->get_ExtURL_link( $_, 'HGVBASE', $_) } @ids;
    } 
    elsif ($db =~ /tsc/i) {
      $display_db = "TSC";
      @urls  = map {  $object->get_ExtURL_link( $_, 'TSC', $_)  } @ids;
    }

    # Do wrapping
    for (my $counter = 7; $counter < $#urls; $counter +=7) {
      my @front = splice (@urls, 0, $counter);
      $front[-1] .= "</tr><tr><td></td>";
      @urls = (@front, @urls);
    }

    $info .= "<b>$display_db</b> ". (join ", ", @urls ). "<br />";
  }

  $info .= "None currently in the database" unless (keys %synonyms);
  $panel->add_row( $label, $info );
  return 1;
}


=head2 status

 Arg1        : panel
 Arg2        : data object
 Example     : $panel1->add_rows("status EnsEMBL::Web::Component::SNP::status");
 Description : adds a label and string for the variation validation status to the panel
 Return type : 1

=cut

sub status {
  my ( $panel, $object ) = @_;
  my $label = 'Validation status';
  my @status = @{$object->status};
  unless ( @status ) {
    $panel->add_row($label, "Unknown");
    return 1;
  }

  my $snp_name = $object->name;
  #     if ($snp_name !~ /^rs/) {
  #       $snp_name = "rs".$snp_name;
  #     }
  my (@status_list, $hapmap_html);
  foreach my $status (@status) {
    if ($status eq 'hapmap') {
      $hapmap_html = "<b>HapMap SNP</b>", $object->get_ExtURL_link($snp_name, 'HAPMAP', $snp_name);
    } else {
      $status = "frequency" if $status eq 'freq';
      push @status_list, $status;
    }
  }

  my $html = join(", ", @status_list);
  if ($html) {
    if ($html eq 'observed' or $html eq 'non-polymorphic') {
      $html = '<b>'.ucfirst($html).'</b>';
    } else {
      $html = "Proven by <b>$html</b>";
    }
    $html .= ' (<i>SNP tested and validated by a non-computational method</i>).<br />';
  }
  $html .= $hapmap_html;
  $panel->add_row($label, $html);
  return 1;
}



=head2 alleles

 Arg1        : panel
 Arg2        : data object
 Example     : $panel1->add_rows(qw(alleles EnsEMBL::Web::Component::SNP::alleles) );
 Description : adds a label and html for the Variations alleles
 Return type : 1

=cut

 sub alleles {
   my ( $panel, $object ) = @_;
   my $label = 'Alleles';
   my $alleles = $object->alleles;
   my $vari_class = $object->vari_class || "Unknown";
   my $html;

   if ($vari_class ne 'snp') {
     $html = qq(<b>$alleles</b> (Type: <b><font color="red">$vari_class</font></b>));
   }
   else {
     my $ambig_code = $object->vari->ambig_code;
     $html = qq(<b>$alleles</b> (ambiguity code: <b><font color="red">$ambig_code</font></b>));
   }
   $panel->add_row($label, $html);
   return 1;
 }


=head2 ld_data

 Arg1        : panel
 Arg2        : data object
 Example     : $panel1->add_rows(qw(ld_data EnsEMBL::Web::Component::SNP::ld_data) );
 Description : adds a label and its value to the panel:
               Get all the populations with LD data within 100kb of this SNP
                 Make links from these populations to LDView
 Return type : 1

=cut

sub ld_data {
  my ( $panel, $object ) = @_;
  my %pop_data = %{ _ld_populations($object) };
  my $label = "Linkage disequilibrium <br />data";

  unless (%pop_data) {
    $panel->add_row($label, "<h5>No linkage data for this SNP</h5>");
    return 1;
  }

  $panel->add_row($label, link_to_ldview($panel, $object, \%pop_data) );
  return 1;
}


=head2 tagged_snp

 Arg1        : panel
 Arg2        : data object
 Example     : $panel1->add_rows(qw(tagged_snp EnsEMBL::Web::Component::SNP::tagged_snp) );
 Description : adds a label and html to the panel
               the populations in which this snp is tagged, if it is tagged an any in two_col_table format
 Return type : 1

=cut

sub tagged_snp {
  my ( $panel, $object ) = @_;
  my $label = 'SNP in tagged set for these populations';
  my $snp_data  = $object->tagged_snp;
  return 1 unless %$snp_data;
  $panel->add_row($label, link_to_ldview($panel, $object, $snp_data) );
  return 1;
}


=head2 seq_region

 Arg1        : panel
 Arg2        : data object
 Example     : $panel1->add_rows(qw(seq_region EnsEMBL::Web::Component::SNP::seq_region) );
 Description : adds a label and html to the panel
               the variations sequence region in two_col_table format
 Return type : 1

=cut

sub seq_region {
  my ( $panel, $object ) = @_;
  my $label = 'Sequence region';
  my $alleles = $object->alleles;
  my $ambig_code = $object->vari->ambig_code;

  unless ($ambig_code) {
    $ambig_code = "[".$alleles."]";
  }
  my $downstream = $object->flanking_seq("down");

  # Make the flanking sequence and wrap it
  my $html = uc( $object->flanking_seq("up") ) .lc( $ambig_code ).uc( $downstream );
  $html =~ s/(.{60})/$1\n/g;
  $html =~ s/(([a-z]|-|\[|\])+)/'<font color="red">'.uc("$1").'<\/font>'/eg;
  $html =~ s/\n/\n/g;
  $html .= "     <i>(SNP highlighted)</i>";
  $panel->add_row($label, "<pre>$html</pre>");
  return 1;
}


# Population genotype table and Allele Frequency Table ######################

=head2 genotype_freqs;

 Arg1        : panel
 Arg2        : data object
 Example     :  $genotype_panel->add_components( qw(genotype_freqs EnsEMBL::Web::Component::SNP::genotype_freqs) ); 
 Description : prints a table of variation genotypes, their Population ids, genotypes, frequencies  etc. in spreadsheet format
 Return type : 1

=cut

sub genotype_freqs {
  my ( $panel, $object ) = @_;
  my $freq_data = $object->pop_table;
  return [] unless %$freq_data;

  format_frequencies($panel, $object, $freq_data, "Genotypes");
  return 1;
}

=head2 allele_freqs

 Arg1        : panel
 Arg2        : data object
 Example     : $allele_panel->add_components( qw(allele_freqs EnsEMBL::Web::Component::SNP::allele_freqs) );
 Description : prints a table of allele frequencies for the variation
 Return type : 1

=cut

sub allele_freqs {
  my ( $panel, $object ) = @_;
  my $freq_data = $object->allele_freqs;
  return [] unless %$freq_data;

  format_frequencies($panel, $object, $freq_data, "Alleles");
  return 1;
}


=head2 format_frequencies

 Arg1        : panel
 Arg2        : data object 
 Arg3        : frequency data
 Arg4        : data type i.e. "Alleles" or "Genotypes"
 Example     : format_frequencies($panel, $object, $freq_data, "Alleles");
 Description : prints a table of allele or genotype frequencies for the variation
 Return type : 1

=cut

sub format_frequencies {
  my ( $panel, $object, $freq_data, $data_type ) = @_;
  my %freq_data = %{ $freq_data };
  my %columns;

  foreach my $pop_id (keys %freq_data) {
    my %pop_row;

    # Freqs and genotypes/alleles ---------------------------------------------
    my @freq = @{ $freq_data{$pop_id}{Frequency} };

    foreach my $gt ( @{ $freq_data{$pop_id}{$data_type} } ) {
      $pop_row{$gt} = sprintf("%.3f", shift @freq ) || 'no data';
    }

    # Add a name, size and description if it exists ---------------------------
    $pop_row{pop}= _pop_url( $object, $freq_data{$pop_id}{pop_info}{Name}, $freq_data{$pop_id}{pop_info}{PopLink})."&nbsp;";
    $pop_row{Size} = $freq_data{$pop_id}{pop_info}{Size};
    $pop_row{Description} = "<small>".($freq_data{$pop_id}{pop_info}{Description}||'-')."</small>";


    # Super and sub populations ----------------------------------------------
    my $super_string = _sort_extra_pops($object, $freq_data{$pop_id}{pop_info}{"Super-Population"});
    $pop_row{"Super-Population"} =  $super_string;

    my $sub_string = _sort_extra_pops($object, $freq_data{$pop_id}{pop_info}{"Sub-Population"});
    $pop_row{"Sub-Population"} =  $sub_string;

    $panel->add_row(\%pop_row); 
    map {  $columns{$_} = 1 if $pop_row{$_};  } (keys %pop_row);
  }


  # Format table columns ------------------------------------------------------
  my @header_row;
  foreach my $col (sort keys %columns) {
    next if $col eq 'pop';
    if ($col !~ /Population|Description/) {
      unshift (@header_row, {key  =>$col,  'align'=>'left',
 			     title => "$data_type&nbsp;<br />$col" });
    }
    else {
      push (@header_row, {key  =>$col, 'align'=>'left', title => "&nbsp;$col&nbsp;"  });
    }
  }
  unshift (@header_row,  {key  =>"pop",'align'=>'left',  title =>"Population"} );

  $panel->add_columns(@header_row);
  return 1;
}

# Variation feature mapping table #############################################

=head2 mappings

 Arg1        : panel
 Arg2        : data object 
 Arg3        : the view name (i.e. "snpview" or "ldview")
 Example     :  $mapping_panel->add_components( qw(mappings EnsEMBL::Web::Component::SNP::mappings) );
 Description : table showing Variation feature mappings to genomic locations
 Return type : 1

=cut

sub mappings {
  my ( $panel, $object, $view ) = @_;
  $view ||= "snpview";
  my %mappings = %{ $object->variation_feature_mapping };
  return [] unless keys %mappings;
  my $source = $object->source;

  my @table_header;
  my $flag_multi_hits = keys %mappings >1 ? 1: 0;
  foreach my $varif_id (keys %mappings) {
    my %chr_info;
    my $region = $mappings{$varif_id}{Chr};
    my $start  = $mappings{$varif_id}{start};
    my $end    = $mappings{$varif_id}{end};
    my $link   = "/@{[$object->species]}/contigview?l=$region:" .($start - 10) ."-" . ($end+10);
    my $strand = $mappings{$varif_id}{strand};
    $strand = " ($strand)&nbsp;" if $strand;
    if ($region) {
      $chr_info{chr} = qq(<span style="white-space: nowrap"><a href="$link">$region: $start-$end</a>$strand</span>);
    } else {
      $chr_info{chr} = "unknown";
    }

    if ($flag_multi_hits) {
      my $vari = $object->name;
      my $link = "SNP maps several times:<br /><a href='$view?snp=$vari&c=$region:$start'>Choose this location</a>";
      my $display = $object->param('c') eq "$region:$start" ?
	"Current location" : $link;
      $chr_info{location} = $display;
    }

    my @transcript_variation_data = @{ $mappings{$varif_id}{transcript_vari} };
    unless( scalar @transcript_variation_data ) {
      last unless $flag_multi_hits;
      $panel->add_row(\%chr_info);
      next;
    }
    foreach my $transcript_data (@transcript_variation_data ) {
      my $transcript_link = qq(<a href='transview?transcript=$transcript_data->{transcriptname}'>$transcript_data->{transcriptname}</a>);
      my $genesnpview = qq(<a href="genesnpview?transcript=$transcript_data->{transcriptname}">SNP in gene context</a>);
      my $protein_link = qq(<a href='protview?transcript=$transcript_data->{transcriptname}'>$transcript_data->{proteinname}</a>);

      my $transcript_coords = _sort_start_end(
                     $transcript_data->{cdna_start}, $transcript_data->{cdna_end});
      my $translation_coords = _sort_start_end(
                     $transcript_data->{translation_start}, $transcript_data->{translation_end});
      my %trans_info = (
			"conseq"     => $transcript_data->{conseq},
			"transcript" => "<nobr>$transcript_link:$transcript_coords </nobr>",
		       );
      unless ($source eq 'Glovar') {
	$trans_info{'genesnpview'} = "$genesnpview";
      }

      if ($transcript_data->{'proteinname'}) {
	$trans_info{'translation'} = "<nobr>$protein_link:$translation_coords </nobr>";
	$trans_info{'pepallele'} = "$transcript_data->{pepallele}";
      }
      $panel->add_row({ %chr_info, %trans_info});

      unless (@table_header) {
	push (@table_header,
	      {key => 'transcript', title => 'Transcript: start-end&nbsp;'},
	     );
	unless ($source eq 'Glovar') {
	  push (@table_header,
		{key => 'genesnpview', title => 'GeneSNPView link&nbsp;'},
	       );
	}
	if ($transcript_data->{'proteinname'}) {
	  push (@table_header, 
		{key => 'translation', title => 'Translation: start-end&nbsp;'},
		{key => 'pepallele',   title =>'Peptide allele&nbsp;'},
	       );
	}
	push (@table_header, {key => 'conseq', title =>'Consequence'});
      }
      %chr_info = ();
    }
  }
  unshift (@table_header,{key =>'location', title => 'Location'}) if $flag_multi_hits;
  unshift (@table_header, {key =>'chr',title => 'Genomic location (strand)'});

  $panel->add_columns(@table_header);
  return 1;
}


=head2 _sort_start_end

 Arg1     : start and end coordinate
 Example  : $coord = _sort_star_end($start, $end)_
 Description : Returns $start-$end if they are defined, else 'n/a'
 Return type : string

=cut

sub _sort_start_end {
  my ( $start, $end ) = @_;
  if ($start or $end){
    return " $start-$end&nbsp;";
  }
  else {return " n/a&nbsp;"};
}

# Location info ###############################################################

=head2 snpview_image_menu

 Arg1     : panel
 Arg2     : data object 
 Example  : $image_panel->add_components(qw(
      menu  EnsEMBL::Web::Component::SNP::snpview_image_menu
      image EnsEMBL::Web::Component::SNP::snpview_image
    ));
 Description : Creates a menu container for snpview and adds it to the panel
 Return type : 0

=cut

sub snpview_image_menu {
  my($panel, $object ) = @_;
  my $user_config = $object->user_config_hash( 'snpview' );
  my $params =  {
		 'h'          => $object->highlights_string || '',
		 'source'     => $object->source || "dbSNP",
		 'snp'        => $object->name || '',
		 'c'          => $object->param('c') || '',
		 'pop'        => $object->get_default_pop_id || '',
		};
  $user_config->set( '_settings', 'URL', "/".$object->species."/snpview?".
    join(";", map { "$_=".CGI::escapeHTML($params->{$_}) } keys %$params ).
      ";snpview=%7Cbump_", 1);
  $user_config->{'_ld_population'} = $object->get_default_pop_id;
  my $mc = $object->new_menu_container( 
    'configname' => 'snpview',
    'panel'      => 'snpview',
    'fields'     => $params,
    'leftmenus'   => [qw(Features Options Export ImageSize)],
    'rightmenus'  => [qw(Help)]
  );
  $panel->print( $mc->render_html );
  $panel->print( $mc->render_js );
  return 0;
}


=head2 snpview_image

 Arg1     : panel
 Arg2     : data object
 Arg[3]   : width (optional)
 Example  : $image_panel->add_components(qw(
      menu  EnsEMBL::Web::Component::SNP::snpview_image_menu
      image EnsEMBL::Web::Component::SNP::snpview_image
    ));
 Description : Creates a drawable container for snpview and adds it to the panel
 Return type : 0

=cut

sub snpview_image {
  my($panel, $object) = @_;
  my $width = $object->param('w') || "100000";
  my ($seq_region, $start, $seq_type ) = $object->seq_region_data;
  return [] unless $seq_region;

  my $end   = $start + ($width/2);
  $start -= ($width/2);
  my $slice =
    $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $seq_type, $seq_region, $start, $end, 1
  );
  my $wuc = $object->user_config_hash( 'snpview' );
     $wuc->set( '_settings', 'width', $object->param('image_width') );

  ## If you want to resize this image
  my $image    = $object->new_image( $slice, $wuc, [$object->name] );
  $image->imagemap = 'yes';
  my $T = $image->render;
  $panel->print( $T );
  return 0;
}


=head2 snpview_noimage

 Arg1     : panel
 Arg2     : data object
 Example  :  $image_panel->add_components(qw(
      no_image EnsEMBL::Web::Component::SNP::snpview_noimage
   ));
 Description : Adds an HTML string to the panel if the SNP cannot be mapped uniquely
 Return type : 1

=cut

sub snpview_noimage {
  my ($panel, $object) = @_;
  $panel->print("<p>Unable to draw SNP neighbourhood as we cannot uniquely determine the SNP's location</p>");
  return 1;
}


# Individual table ############################################################

=head2 individual

 Arg1        : panel
 Arg2        : data object
 Example     : $object->outputIndGenotypeTable
 Description : adds a table of Individual genotypes, their refSNP ssids, allele, sex etc. in spreadsheet format to the panel
 Return type : 1

=cut

sub individual {
  my ( $panel, $object) = @_;
  my %ind_data = %{ $object->individual_table };
  unless (%ind_data) {
    $panel->print("<p>No individual genotypes for this SNP</p>");
    return 1;
  }
  # Create header row for output table ---------------------------------------
  my @rows;
  my %columns;
  my $flag_children = 0;

  foreach my $ind_id (keys %ind_data ) { 
    my %ind_row;
    my $genotype = $ind_data{$ind_id}{Genotypes}; 
    next if $genotype eq '(indeterminate)';

    # Parents -----------------------------------------------------------------
    my $father = _format_parent($object, $ind_data{$ind_id}{Father} );
    my $mother = _format_parent($object, $ind_data{$ind_id}{Mother} );


    # Name, Gender, Desc ------------------------------------------------------
    my $description = uc($ind_data{$ind_id}{Description});
    my @populations = map {_pop_url( $object, $_->{Name}, $_->{Link} ) } @{ $ind_data{$ind_id}{Population} };

    my $pop_string = join ", ", @populations;
    my %tmp_row =  (
		  Individual => $ind_data{$ind_id}{Name}."<br />(".
		    $ind_data{$ind_id}{Gender}.")",
		  Genotype   => $genotype,
		  Description=> $description ? "<small>$description</small>" : "<small>-</small>", 
                  Populations=> $pop_string  ? "<small>$pop_string</small>"  : "<small>-</small>",
		  Father     => $father      ? "<small>$father</small>"      : "<small>-</small>", 
		  Mother     => $mother      ? "<small>$mother</small>"      : "<small>-</small>", 
		  );


    #  Children  -------------------------------------------------------------
    my $children =  $ind_data{$ind_id}{Children};
    $tmp_row{Children} = "-";

    my @children = map {"<small>$_: ".$children->{$_}[0]."</small>"} (keys %$children);

    if (@children) {
      $tmp_row{Children} = join "<br />", @children;
      $flag_children = 1;
    }
    $panel->add_row(\%tmp_row);
  }


  my @header_row = ({key =>"Individual", title =>"Individual<br />(Gender)"} );
  push (@header_row, 
	{key  =>"Genotype",    title => "Genotype"},
	{key  =>"Description", title => "Description"},
	{key  =>"Populations", title => "Populations", width=>"250"}, 
	{key  =>"Father",      title => "Father"},
	{key  =>"Mother",      title => "Mother"} );

  push (@header_row, {key =>"Children", title =>"Children"}) if $flag_children;

  $panel->add_columns(@header_row);
  return 1;
}


###############################################################################
#               INTERNAL CALLS
###############################################################################


# Internal: Population table #################################################

=head2 _sort_extra_pops

    Arg1      : data object
    Arg2      : hashref with population data
    Example   :     my $super_string = _sort_extra_pops($object, $freq_data{$pop_id}{pop_info}{"Super-Population"});
    Description : returns string with Population name (size)<br> description
    Return type : string

=cut

sub _sort_extra_pops {
  my ( $object, $extra_pop ) = @_;

  my @pops;
  foreach my $pop_id (keys %$extra_pop  ) {
    my $display_pop = _pop_url( $object, $extra_pop->{$pop_id}{Name}, 
 				       $extra_pop->{$pop_id}{PopLink});
    my $size = $extra_pop->{$pop_id}{Size};
    $size = " (Size: $size)" if $size;
    my $string = "$display_pop $size";
       $string .= "<br /><small>".$extra_pop->{$pop_id}{Description}."</small>" if $extra_pop->{$pop_id}{Description};
  }
  return  (join "<br />", @pops);
}


=head2 _pop_url  ## ALSO IN LD RENDERER

   Arg1        : data object
   Arg2        : Population name (to be displayed)
   Arg3        : dbSNP population ID (variable to be linked to)
   Example     : _pop_url($object, $pop_name, $pop_dbSNPID);
   Description : makes pop_name into a link
   Return type : string

=cut

sub _pop_url {
  my ($object, $pop_name, $pop_dbSNP) = @_;
  return $pop_name unless $pop_dbSNP;
  return $object->get_ExtURL_link( $pop_name, 'DBSNPPOP',$pop_dbSNP->[0] );
}


# Internal: Individual table calls ###########################################

=head2 _format_parent

  Arg[1]      : data object
  Arg2        : parent data 
  Example     : format_parent(
                  $object->parent($object, $ind_genotype,"father") );
  Description : Formats output 
  Return type : string

=cut

sub _format_parent {
  my $object        = shift;
  my $parent_data = shift;
  return "-" unless $parent_data;

  my $string = $parent_data->{Name};
  return $string;
}


# Internal: LD related calls #################################################

=head2 link_to_ldview

   Arg1        : panel
   Arg2        : object
   Arg3        : population data
   Example     : link_to_ldview($panel, $object, \%pop_data);
   Description : Make links from these populations to LDView
   Return type : Table of HTML links to LDView

=cut

sub link_to_ldview {
  my ($panel, $object, $pop_data ) = @_;
  my $output = "<table width='100%' class='hidden' border=0><tr>";
  $output .="<td> <b>Links to LDview per population:</b></td></tr><tr>";
  my $count = 0;
  for my $pop_id (keys %$pop_data) {
    $count++;
    my $name = $pop_data->{$pop_id};
    $output .= "<td><a href='ldview?snp=". $object->name;
    $output .=  "&amp;c=".$object->param('c') if $object->param('c');
    $output .=  "&amp;w=".($object->param('w') || "20000");
    $output .=	"&amp;pop=$pop_id'>$name</a></td>";
    if ($count ==4) {
      $count = 0;
      $output .= "</tr><tr>";
    }
  }
  $output .= "</tr></table>";
  return  $output;
}

=head2 _ld_populations

   Arg1        : object
   Example     : ld_populations()
   Description : data structure with population id and name of pops 
                 with LD info for this SNP
   Return type : hashref

=cut

sub _ld_populations {
  my $object = shift;
  my $pop_data = $object->ld_for_slice("", 100000); # all pops, slice width
  return {} unless %$pop_data;
  my @pop_ids = (keys %{ $pop_data->{'_pop_ids'} } );
  return {} if scalar @pop_ids < 1 ;

  my %pops;
  foreach (@pop_ids) {
    my $pop_obj = $object->pop_obj_from_id($_);
    my $name = $pop_obj->{$_}{Name};
    $pops{$_} = $name;
  }
  return \%pops;
}


1;
