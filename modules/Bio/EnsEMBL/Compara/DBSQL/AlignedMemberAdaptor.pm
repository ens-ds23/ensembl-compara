=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::AlignedMemberAdaptor

=head1 DESCRIPTION

Adaptor to fetch AlignedMember objects, grouped within a multiple
alignment.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::AlignedMemberAdaptor
  `- Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::DBSQL::AlignedMemberAdaptor;

use strict; 
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;
use DBI qw(:sql_types);

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');

#
# FETCH methods
###########################

=head2 fetch_all_by_AlignedMemberSet

  Arg[1]     : AlignedMemberSet $set: Currently, Family, Homology and GeneTree
                are supported
  Example    : $family_members = $am_adaptor->fetch_all_by_AlignedMemberSet($family);
  Description: Fetches from the database all the aligned members (members with
                an alignment string)
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_AlignedMemberSet {
    my ($self, $set) = @_;
    assert_ref($set, 'Bio::EnsEMBL::Compara::AlignedMemberSet');

    if (UNIVERSAL::isa($set, 'Bio::EnsEMBL::Compara::Homology')) {
        return $self->fetch_all_by_Homology($set);
    } elsif (UNIVERSAL::isa($set, 'Bio::EnsEMBL::Compara::Family')) {
        return $self->fetch_all_by_Family($set);
    } elsif (UNIVERSAL::isa($set, 'Bio::EnsEMBL::Compara::GeneTree')) {
        return $self->fetch_all_by_GeneTree($set);
    } else {
        return $self->fetch_all_by_gene_align_id($set->dbID);
    }
}

=head2 fetch_all_by_Homology

  Arg[1]     : Homology $homology
  Example    : $hom_members = $am_adaptor->fetch_all_by_AlignedMemberSet($homology);
  Description: Fetches from the database the two aligned members related to
                this Homology object
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_Homology {
    my ($self, $homology) = @_;
    assert_ref($homology, 'Bio::EnsEMBL::Compara::Homology');

    my $extra_columns = ['hm.cigar_line', 'hm.perc_cov', 'hm.perc_id', 'hm.perc_pos'];
    my $join = [[['homology_member', 'hm'], 'm.member_id = hm.peptide_member_id', $extra_columns]];
    my $constraint = 'hm.homology_id = ?';

    $self->bind_param_generic_fetch($homology->dbID, SQL_INTEGER);
    return $self->generic_fetch($constraint, $join);
}

=head2 fetch_all_by_Family

  Arg[1]     : Family $family
  Example    : $family_members = $am_adaptor->fetch_all_by_Family($family);
  Description: Fetches from the database all the aligned members of that family.
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_Family {
    my ($self, $family) = @_;
    assert_ref($family, 'Bio::EnsEMBL::Compara::Family');

    my $extra_columns = ['fm.cigar_line'];
    my $join = [[['family_member', 'fm'], 'm.member_id = fm.member_id', $extra_columns]];
    my $constraint = 'fm.family_id = ?';
    my $final_clause = 'ORDER BY m.source_name';

    $self->bind_param_generic_fetch($family->dbID, SQL_INTEGER);
    return $self->generic_fetch($constraint, $join, $final_clause);
}

=head2 fetch_all_by_GeneTree

  Arg[1]     : GeneTree $tree
  Example    : $tree_members = $am_adaptor->fetch_all_by_GeneTree($tree);
  Description: Fetches from the database all the leaves of the tree, with respect
                to their multiple alignment
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_GeneTree {
    my ($self, $tree) = @_;
    assert_ref($tree, 'Bio::EnsEMBL::Compara::GeneTree');

    return $self->fetch_all_by_gene_align_id($tree->gene_align_id);
}


=head2 fetch_all_by_gene_align_id

  Arg[1]     : integer $id
  Example    : $aln_members = $am_adaptor->fetch_all_by_gene_align_id($id);
  Description: Fetches from the database all the members of an alignment,
                based on its dbID
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_gene_align_id {
    my ($self, $id) = @_;

    my $extra_columns = ['gam.cigar_line'];
    my $join = [[['gene_align_member', 'gam'], 'm.member_id = gam.member_id', $extra_columns]];
    my $constraint = 'gam.gene_align_id = ?';

    $self->bind_param_generic_fetch($id, SQL_INTEGER);
    return $self->generic_fetch($constraint, $join);
}


#
# Store an AlignedMemberSet
##############################

=head2 store

 Arg [1]    : Bio::EnsEMBL::Compara::AlignedMemberSet $aln
 Example    : $AlignedMemberAdaptor->store($fam)
 Description: Stores an AlignedMemberSet object into a Compara database
 Returntype : none
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::AlignedMemberSet
 Caller     : general

=cut

sub store {
    my ($self, $aln) = @_;
    assert_ref($aln, 'Bio::EnsEMBL::Compara::AlignedMemberSet');
  
    # dbID for GeneTree is too dodgy
    my $id = $aln->isa('Bio::EnsEMBL::Compara::GeneTree') ? $aln->gene_align_id() : $aln->dbID();

    if ($id) {
        my $sth = $self->prepare('UPDATE gene_align SET seq_type = ?, aln_length = ?, aln_method = ? WHERE gene_align_id = ?');
        $sth->execute($aln->seq_type, $aln->aln_length, $aln->aln_method, $id);
    } else {
        my $sth = $self->prepare('INSERT INTO gene_align (seq_type, aln_length, aln_method) VALUES (?,?,?)');
        $sth->execute($aln->seq_type, $aln->aln_length, $aln->aln_method);
        $id = $sth->{'mysql_insertid'};

        if ($aln->isa('Bio::EnsEMBL::Compara::GeneTree')) {
            $aln->gene_align_id($id);
        } else {
            $aln->dbID($id);
        }
    }
 
    my $sth = $self->prepare('REPLACE INTO gene_align_member (gene_align_id, member_id, cigar_line) VALUES (?,?,?)');

    foreach my $member (@{$aln->get_all_Members}) {
        $sth->execute($id, $member->member_id, $member->cigar_line) if $member->cigar_line;
    }

    $sth->finish;

    # let's store the link between gene_tree_root and gene_align
    if ($aln->isa('Bio::EnsEMBL::Compara::GeneTree') and defined $aln->root_id) {
        $sth = $self->prepare('UPDATE gene_tree_root SET gene_align_id = ? WHERE root_id = ?');
        $sth->execute($aln->gene_align_id,  $aln->root_id);
        $sth->finish;
    }

}


#
# Redirections to MemberAdaptor
################################

sub _tables {
    return Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor::_tables();
}

sub _columns {
    return Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor::_columns();
}

sub _objs_from_sth {
    my ($self, $sth) = @_;

    my @members = ();

    while(my $rowhash = $sth->fetchrow_hashref) {
        my $member = Bio::EnsEMBL::Compara::AlignedMember->new;
        $member = Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor::init_instance_from_rowhash($self, $member, $rowhash);
        foreach my $attr (qw(cigar_line cigar_start cigar_end perc_cov perc_id perc_pos)) {
            $member->$attr($rowhash->{$attr}) if defined $rowhash->{$attr};
        }
        push @members, $member;
    }
    $sth->finish;
    return \@members
}


1;

