=head1 NAME Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor

=head1 SYNOPSIS

=head1 CONTACT

  Michele Clamp : michele@sanger.ac.uk

=head1 APPENDIX

=cut


package Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
#use Bio::EnsEMBL::Compara::SyntenyPair;
use Bio::EnsEMBL::Compara::PeptideAlignFeature;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;
use Bio::EnsEMBL::GenePair::PeptidePair;

use vars '@ISA';

@ISA = ('Bio::EnsEMBL::DBSQL::BaseAdaptor');

=head2
sub get_hits_by_qyid {
  my ($self,$id) = @_;

  my $idlength = $self->get_peptide_length($id);

  my $command = "select peptide.length,feature.* from peptide,feature where feature.id1 = \'$id\' and feature.id2 = peptide.id";

  my $sth = $self->db->prepare($command);
  my $res = $sth->execute;

  my @hits;

  while (my $row = $sth->fetchrow_hashref) {

    my $p = new Bio::EnsEMBL::GenePair::PeptidePair;

    $p->queryid($row->{id1});
    $p->hitid  ($row->{id2});
    $p->qstart ($row->{qstart});
    $p->qend   ($row->{qend});
    $p->hstart ($row->{hstart});
    $p->hend   ($row->{hend});
    $p->score  ($row->{score});
    $p->evalue ($row->{evalue});
    $p->pid    ($row->{pid});
    $p->qlength($idlength);
    $p->hlength($row->{length});

    $p->pos    ($row->{pos});
    $p->identical_matches    ($row->{identical_matches});
    $p->positive_matches    ($row->{positive_matches});
    $p->cigar_line    ($row->{cigar_line});

    push(@hits,$p);

  }
  return @hits;
}

sub get_hits_by_qyid_and_hitid {
  my ($self,$id,$hitid) = @_;

  my $idlength = $self->get_peptide_length($id);

  my $command = "select peptide.length,feature.* from peptide,feature where feature.id1 = \'$id\' and feature.id2 = peptide.id and feature.id2 = \'$hitid\'";

  my $sth = $self->db->prepare($command);
  my $res = $sth->execute;

  my @hits;

  while (my $row = $sth->fetchrow_hashref) {

    my $p = new Bio::EnsEMBL::GenePair::PeptidePair;

    $p->queryid($row->{id1});
    $p->hitid $self->{'comparaDBA'} ($row->{id2});
    $p->qstart ($row->{qstart});
    $p->qend   ($row->{qend});
    $p->hstart ($row->{hstart});
    $p->hend   ($row->{hend});
    $p->score  ($row->{score});
    $p->evalue ($row->{evalue});
    $p->pid    ($row->{pid});
    $p->qlength($idlength);
    $p->hlength($row->{length});

    $p->pos    ($row->{pos});
    $p->identical_matches    ($row->{identical_matches});
    $p->positive_matches    ($row->{positive_matches});
    $p->cigar_line    ($row->{cigar_line});

    push(@hits,$p);

  }
  return @hits;
}
=cut

#############################
#
# store methods
#
#############################

sub store {
  my ($self, @features)  = @_;

  my @pafList = ();

  foreach my $feature (@features) {
    if($feature->isa('Bio::EnsEMBL::BaseAlignFeature')) {
      #displayHSP_short($feature);
      my $pepFeature = new Bio::EnsEMBL::Compara::PeptideAlignFeature(-feature => $feature);
      #displayPAF_short($pepFeature);
      push @pafList, $pepFeature;
    }
    elsif($feature->isa('Bio::EnsEMBL::Compara::PeptideAlignFeature')) {
      push @pafList, $pepFeature;
    }
  }

  @pafList = sort sort_by_score_evalue_and_pid @pafList;
  my $rank=1;
  foreach my $feature (@pafList) {
    $feature->hit_rank($rank++);
  }

  $self->_store_PAFS(@pafList);
}

sub _store_PAFS {
  my ($self, @out)  = @_;

  my $memberDBA = $self->db->get_MemberAdaptor();

  my $query = "INSERT INTO peptide_align_feature(".
                "qmember_id,hmember_id,analysis_id," .
                "qstart,qend,hstart,hend,".
                "score,evalue,align_length," .
                "identical_matches,perc_ident,".
                "positive_matches,perc_pos,hit_rank,cigar_line) ".
              " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
  my $sth = $self->db->prepare($query);

  foreach my $paf (@out) {
    if($paf->isa('Bio::EnsEMBL::Compara::PeptideAlignFeature')) {

      unless($paf->query_member->dbID) {
        my $qy_member  = $memberDBA->fetch_by_source_stable_id('ENSEMBLPEP', $paf->query_member->stable_id);
        $paf->query_member($qy_member);
      }
      unless($paf->hit_member->dbID) {
        my $hit_member = $memberDBA->fetch_by_source_stable_id('ENSEMBLPEP', $paf->hit_member->stable_id);
        $paf->hit_member($hit_member);
      }

      displayPAF_short($paf);

      my $analysis_id = 0;
      if($paf->analysis()) {
        #print("paf has analysis '".$paf->analysis->logic_name()."' dbID=".$paf->analysis->dbID."\n");
        $analysis_id=$paf->analysis()->dbID();
      }

      $sth->execute($paf->query_member->dbID,
                    $paf->hit_member->dbID,
                    $analysis_id,
                    $paf->qstart,
                    $paf->qend,
                    $paf->hstart,
                    $paf->hend,
                    $paf->score,
                    $paf->evalue,
                    $paf->alignment_length,
                    $paf->identical_matches,
                    $paf->perc_ident,
                    $paf->positive_matches,
                    $paf->perc_pos,
                    $paf->hit_rank,
                    $paf->cigar_line
                   );
      $paf->dbID($sth->{'mysql_insertid'});
    }
  }
}


sub sort_by_score_evalue_and_pid {
  $b->score <=> $a->score ||
    $a->evalue <=> $b->evalue ||
      $b->perc_ident <=> $a->perc_ident ||
        $b->perc_pos <=> $a->perc_pos;
}


sub displayHSP {
  my($paf) = @_;

  my $percent_ident = int($paf->identical_matches*100/$paf->alignment_length);
  my $pos = int($paf->positive_matches*100/$paf->alignment_length);

  print("=> $paf\n");
  print("pep_align_feature :\n" .
    " seqname           : " . $paf->seqname . "\n" .
    " start             : " . $paf->start . "\n" .
    " end               : " . $paf->end . "\n" .
    " hseqname          : " . $paf->hseqname . "\n" .
    " hstart            : " . $paf->hstart . "\n" .
    " hend              : " . $paf->hend . "\n" .
    " score             : " . $paf->score . "\n" .
    " p_value           : " . $paf->p_value . "\n" .
    " alignment_length  : " . $paf->alignment_length . "\n" .
    " identical_matches : " . $paf->identical_matches . "\n" .
    " perc_ident        : " . $percent_ident . "\n" .
    " positive_matches  : " . $paf->positive_matches . "\n" .
    " perc_pos          : " . $pos . "\n" .
    " cigar_line        : " . $paf->cigar_string . "\n");
}

sub displayHSP_short {
  my($paf) = @_;

  unless(defined($paf)) {
    print("qy_stable_id\t\t\thit_stable_id\t\t\tscore\talen\t\%ident\t\%positive\n");
    return;
  }
  
  my $perc_ident = int($paf->identical_matches*100/$paf->alignment_length);
  my $perc_pos = int($paf->positive_matches*100/$paf->alignment_length);

  print("HSP ".$paf->seqname."(".$paf->start.",".$paf->end.")".
        "\t" . $paf->hseqname. "(".$paf->hstart.",".$paf->hend.")".
        "\t" . $paf->score .
        "\t" . $paf->alignment_length .
        "\t" . $perc_ident . 
        "\t" . $perc_pos . "\n");
}

sub displayPAF_short {
  my($paf) = @_;

  unless(defined($paf)) {
    print("qy_stable_id\t\t\thit_stable_id\t\t\tscore\talen\t\%ident\t\%positive\thit_rank\n");
    return;
  }

  print("PAF ".$paf->query_member->stable_id."(".$paf->qstart.",".$paf->qend.")".
        "\t" . $paf->hit_member->stable_id. "(".$paf->hstart.",".$paf->hend.")".
        "\t" . $paf->score .
        "\t" . $paf->alignment_length .
        "\t" . $paf->perc_ident .
        "\t" . $paf->perc_pos .
        "\t" . $paf->hit_rank .
        "\n");
}


############################
#
# INTERNAL METHODS
# (pseudo subclass methods)
#
############################

#internal method used in multiple calls above to build objects from table data

sub _tables {
  my $self = shift;

  return (['peptide_align_feature', 'paf'] );
}

sub _columns {
  my $self = shift;

  return qw (paf.peptide_align_feature_id
             paf.qmember_id
             paf.hmember_id
             paf.analysis_id
             paf.qstart
             paf.qend
             paf.hstart
             paf.hend
             paf.score
             paf.evalue
             paf.align_length
             paf.identical_matches
             paf.perc_ident
             paf.positive_matches
             paf.perc_pos
             paf.hit_rank
             paf.cigar_line
            );
}

sub _default_where_clause {
  my $self = shift;
  return '';
}

sub _final_clause {
  my $self = shift;
  return '';
}


sub _objs_from_sth {
  my ($self, $sth) = @_;

  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @pafs = ();

  while ($sth->fetch()) {
    my $paf;

    $paf = Bio::EnsEMBL::Compara::PeptideAlignFeature->new();

    $paf->dbID($column{'peptide_align_feature_id'});
    $paf->qstart($column{'qstart'});
    $paf->qend($column{'qend'});
    $paf->hstart($column{'hstart'});
    $paf->hend($column{'hend'});
    $paf->score($column{'score'});
    $paf->evalue($column{'evalue'});
    $paf->alignment_length($column{'align_length'});
    $paf->identical_matches($column{'identical_matches'});
    $paf->perc_ident($column{'perc_ident'});
    $paf->positive_matches($column{'positive_matches'});
    $paf->perc_pos($column{'perc_pos'});
    $paf->hit_rank($column{'hit_rank'});
    $paf->cigar_line($column{'cigar_line'});

    if($column{'analysis_id'} and $self->db->get_AnalysisAdaptor) {
      $paf->analysis($self->db->get_AnalysisAdaptor->fetch_by_dbID($column{'analysis_id'}));
    }

    my $memberDBA = $self->db->get_MemberAdaptor;
    if($column{'qmember_id'} and $memberDBA) {
      $paf->query_member($memberDBA->fetch_by_dbID($column{'qmember_id'}));
    }
    if($column{'hmember_id'} and $memberDBA) {
      $paf->hit_member($memberDBA->fetch_by_dbID($column{'hmember_id'}));
    }
  
    displayPAF_short($paf);
    
    push @pafs, $paf;

  }
  return \@pafs
}



###############################################################################
#
# General access methods that could be moved
# into a superclass
#
###############################################################################

=head2 list_internal_ids

  Arg        : None
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub list_internal_ids {
  my $self = shift;

  my @tables = $self->_tables;
  my ($name, $syn) = @{$tables[0]};
  my $sql = "SELECT ${syn}.${name}_id from ${name} ${syn}";

  my $sth = $self->prepare($sql);
  $sth->execute;

  my $internal_id;
  $sth->bind_columns(\$internal_id);

  my @internal_ids;
  while ($sth->fetch()) {
    push @internal_ids, $internal_id;
  }

  $sth->finish;

  return \@internal_ids;
}

=head2 fetch_by_dbID

  Arg [1]    : int $id
               the unique database identifier for the feature to be obtained
  Example    : $feat = $adaptor->fetch_by_dbID(1234);
  Description: Returns the Member created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::Compara::Member
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_by_dbID{
  my ($self,$id) = @_;

  unless(defined $id) {
    $self->throw("fetch_by_dbID must have an id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${syn}.${name}_id = $id";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}


=head2 fetch_all

  Arg        : None
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub fetch_all {
  my $self = shift;

  return $self->_generic_fetch();
}

=head2 _generic_fetch

  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
  Arg [2]    : (optional) string $logic_name
               the logic_name of the analysis of the features to obtain
  Example    : $fts = $a->_generic_fetch('contig_id in (1234, 1235)', 'Swall');
  Description: Performs a database fetch and returns feature objects in
               contig coordinates.
  Returntype : listref of Bio::EnsEMBL::SeqFeature in contig coordinates
  Exceptions : none
  Caller     : BaseFeatureAdaptor, ProxyDnaAlignFeatureAdaptor::_generic_fetch

=cut

sub _generic_fetch {
  my ($self, $constraint, $join) = @_;

  my @tables = $self->_tables;
  my $columns = join(', ', $self->_columns());

  if ($join) {
    foreach my $single_join (@{$join}) {
      my ($tablename, $condition, $extra_columns) = @{$single_join};
      if ($tablename && $condition) {
        push @tables, $tablename;

        if($constraint) {
          $constraint .= " AND $condition";
        } else {
          $constraint = " $condition";
        }
      }
      if ($extra_columns) {
        $columns .= ", " . join(', ', @{$extra_columns});
      }
    }
  }

  #construct a nice table string like 'table1 t1, table2 t2'
  my $tablenames = join(', ', map({ join(' ', @$_) } @tables));

  my $sql = "SELECT $columns FROM $tablenames";

  my $default_where = $self->_default_where_clause;
  my $final_clause = $self->_final_clause;

  #append a where clause if it was defined
  if($constraint) {
    $sql .= " WHERE $constraint ";
    if($default_where) {
      $sql .= " AND $default_where ";
    }
  } elsif($default_where) {
    $sql .= " WHERE $default_where ";
  }

  #append additional clauses which may have been defined
  $sql .= " $final_clause";

  my $sth = $self->prepare($sql);
  $sth->execute;

#  print STDERR $sql,"\n";

  return $self->_objs_from_sth($sth);
}
1;
