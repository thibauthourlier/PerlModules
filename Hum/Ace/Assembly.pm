
### Hum::Ace::Assembly

package Hum::Ace::Assembly;

use strict;

use Carp;

use Hum::Ace::Locus;
use Hum::Ace::Method;
use Hum::Ace::SubSeq;
use Hum::Ace::Clone;
use Hum::Ace::SeqFeature::Simple;
use Hum::Ace::MethodCollection;
use Hum::Sort qw{ ace_sort };
use Hum::Sequence::DNA;

sub new {
    my( $pkg ) = shift;
    
    return bless {
        '_SubSeq_list'  => [],
        }, $pkg;
}

sub name {
    my( $self, $name ) = @_;
    
    if ($name) {
        $self->{'_name'} = $name;
    }
    return $self->{'_name'};
}

sub assembly_name { # or asm_type, or sequence_set_name
    my( $self, $aname ) = @_;
    
    if ($aname) {
        $self->{'_aname'} = $aname;
    }
    return $self->{'_aname'};
}

sub species { # in fact, it is the dataset_name (so 'human' and 'test_human' are different species!)
    my( $self, $species ) = @_;
    
    if ($species) {
        $self->{'_species'} = $species;
    }
    return $self->{'_species'};
}

sub Sequence {
    my( $self, $seq ) = @_;
    
    if ($seq) {
        $self->{'_sequence_dna_object'} = $seq;
    }
    return $self->{'_sequence_dna_object'};
}

sub MethodCollection {
    my( $self, $MethodCollection ) = @_;
    
    if ($MethodCollection) {
        $self->{'_MethodCollection'} = $MethodCollection;
    }
    return $self->{'_MethodCollection'};
}

sub add_SubSeq {
    my( $self, $SubSeq ) = @_;
    
    confess "'$SubSeq' is not a 'Hum::Ace::SubSeq'"
        unless $SubSeq->isa('Hum::Ace::SubSeq');
    push(@{$self->{'_SubSeq_list'}}, $SubSeq);
}

sub replace_SubSeq {
    my( $self, $sub, $old_name ) = @_;
    
    my $name = $old_name || $sub->name;
    my $ss_list = $self->{'_SubSeq_list'}
        or confess "No SubSeq list";
    for (my $i = 0; $i < @$ss_list; $i++) {
        my $this = $ss_list->[$i];
        if ($this->name eq $name) {
            splice(@$ss_list, $i, 1, $sub);
            return 1;
        }
    }
    confess "No such SubSeq '$name' to replace";
}

sub delete_SubSeq {
    my( $self, $name ) = @_;
    
    my $ss_list = $self->{'_SubSeq_list'}
        or confess "No SubSeq list";
    for (my $i = 0; $i < @$ss_list; $i++) {
        my $this = $ss_list->[$i];
        if ($this->name eq $name) {
            splice(@$ss_list, $i, 1);
            return 1;
        }
    }
    confess "No such SubSeq to delete '$name'";
}

sub get_all_SubSeqs {
    my( $self ) = @_;
    
    return @{$self->{'_SubSeq_list'}};
}

sub set_SubSeq_locus_level_errors {
    my ($self) = @_;
    
    my %locus_sub;
    
    foreach my $sub (sort { ace_sort($a->name, $b->name) } $self->get_all_SubSeqs) {
        next unless $sub->is_mutable;
        my $tsct_list = $locus_sub{$sub->Locus->name} ||= [];
        push(@$tsct_list, $sub);
    }
    
    foreach my $loc_name (keys %locus_sub) {
        my $tsct_list = $locus_sub{$loc_name};

        ### Could check that we actually have the same locus
        ### object in memory attached to all its sequences.
        ### Would be v. bad if it wasn't!
        my $locus = $tsct_list->[0]->Locus;
        
        # Is there anything wrong with the annotation of this locus?
        my $locus_err = $locus->pre_otter_save_error;
        foreach my $sub (@$tsct_list) {
            # Need to set on all transcripts since error
            # may have been fixed.
            $sub->locus_level_errors($locus_err);
        }

        $self->error_more_than_one_locus_name_root_in_transcript_names($tsct_list);
        $self->error_strand_in_transcript_set($tsct_list);
        $self->error_evidence_used_more_than_once_in_transcript_set($tsct_list);
    }
    
    $self->error_same_locus_name_root_in_transcripts_on_different_loci;
}

sub error_same_locus_name_root_in_transcripts_on_different_loci {
    my ($self) = @_;
    
    # Check we don't have same locus name root in transcript names
    # shared amongst different loci.
    
    my %root_locus_tsct;
    foreach my $sub (sort { ace_sort($a->name, $b->name) } $self->get_all_SubSeqs) {
        next unless $sub->is_mutable;
        my $root = $sub->locus_name_root;
        my $sub_list = $root_locus_tsct{$root}{$sub->Locus->name} ||= [];
        push @$sub_list, $sub;
    }
    
    foreach my $root (keys %root_locus_tsct) {
        my $locus_tsct = $root_locus_tsct{$root};
        my @loc_name = sort { ace_sort($a, $b) } keys %$locus_tsct;
        next if @loc_name == 1;
        my $other_loci_error;
        for (my $i = 0; $i < @loc_name; $i++) {
            my @others = @loc_name;
            my $this = splice(@others, $i, 1);
            $other_loci_error = sprintf "Locus name root '%s' is used in other %s %s\n",
                $root,
                @others > 1 ? 'loci' : 'locus',
                join(' and ', map "'$_'", @others);
            foreach my $sub (@{$locus_tsct->{$this}}) {
                my $err = $sub->locus_level_errors;
                $sub->locus_level_errors($err . $other_loci_error);
            }
        }
    }
}

sub error_more_than_one_locus_name_root_in_transcript_names {
    my ($self, $tsct_list) = @_;
    
    # Check that we don't have different locus name roots within
    # transcript names from the same locus.

    my %lnr;
    foreach my $sub (@$tsct_list) {
        my $by_root = $lnr{$sub->locus_name_root} ||= [];
        push @$by_root, $sub;
    }
    
    # Return if we've only got one root
    return unless keys %lnr > 1;
    
    my ($most, @rest) = sort { @{$lnr{$b}} <=> @{$lnr{$a}} } keys %lnr;
    if (@{$lnr{$most}} > @{$lnr{$rest[0]}}) {
        # One root is used more frequently than others in locus
        foreach my $root (@rest) {
            foreach my $sub (@{$lnr{$root}}) {
                my $err = $sub->locus_level_errors;
                $err .= "In locus this transcript has name root '$root', but more in locus use '$most'\n";
                $sub->locus_level_errors($err);
            }
        }
    } else {
        # There isn't a name root which is used more frequently than any of the others
        my @all_root = sort { ace_sort($a, $b) } keys %lnr;
        for (my $i = 0; $i < @all_root; $i++) {
            my @others = @all_root;
            my $this = splice(@others, $i, 1);
            my $other_count = 0;
            foreach my $root (@others) {
                $other_count += @{$lnr{$root}};
            }
            my $this_err_msg = sprintf "In locus this transcript has name root '%s' but other transcript%s root%s %s\n",
                $this,
                $other_count > 1 ? 's have' : ' has',
                @others > 1 ? 's' : '',
                join(' or ', map "'$_'", @others);
            foreach my $sub (@{$lnr{$this}}) {
                my $err = $sub->locus_level_errors;
                $sub->locus_level_errors($err . $this_err_msg);
            }
        }
    }
}

sub error_strand_in_transcript_set {
    my ($self, $tsct_list) = @_;

    my $locus_name = $tsct_list->[0]->Locus->name;

    # Find out which strand the locus is on
    my $fwd = 0;
    my $rev = 0;
    foreach my $sub (@$tsct_list) {
        if ($sub->strand == 1) {
            $fwd++;
        } else {
            $rev++;
        }
    }

    # Save strandedness errors in each transcript
    foreach my $sub (@$tsct_list) {
        my $err = $sub->locus_level_errors;
        if ($sub->strand == 1) {
            if ($rev and $rev >= $fwd) {
                $err .= sprintf qq{Transcript is forward strand but %s in Locus '%s' %s reverse\n},
                    $rev > 1 ? $rev : 'the other transcript',
                    $locus_name,
                    $rev > 1 ? 'are' : 'is';
            }
        } else {
            if ($fwd and $fwd >= $rev) {
                $err .= sprintf qq{Transcript is reverse strand but %s in Locus '%s' %s forward\n},
                    $fwd > 1 ? $fwd : 'the other transcript',
                    $locus_name,
                    $fwd > 1 ? 'are' : 'is';
            }
        }
        $sub->locus_level_errors($err);
    }
}

sub error_evidence_used_more_than_once_in_transcript_set {
    my ($self, $tsct_list) = @_;
    
    # Check that the same piece of evidence is not used in more than one transcript.
    my %evi_tsct;

    foreach my $sub (@$tsct_list) {
        my $evi_hash = $sub->evidence_hash;
        foreach my $type (sort keys %$evi_hash) {
            next if $type eq 'Protein';
            my $evi_list = $evi_hash->{$type};
            foreach my $evi_name (@$evi_list) {
                my $sub_list = $evi_tsct{"$type $evi_name"} ||= [];
                push(@$sub_list, $sub);
            }
        }
    }
    
    foreach my $type_evi (sort { ace_sort($a, $b) } keys %evi_tsct) {
        my $sub_list = $evi_tsct{$type_evi};
        if (@$sub_list > 1) {
            for (my $i = 0; $i < @$sub_list; $i++) {
                my $sub = $sub_list->[$i];
                my $error = $sub->locus_level_errors;
                for (my $j = 0; $j < @$sub_list; $j++) {
                    next if $i == $j;
                    $error .= sprintf "Evidence %s is also used in transcript %s\n",
                        $type_evi, $sub_list->[$j]->name;
                }
                $sub->locus_level_errors($error);
            }
        }
    }
}

sub clear_SimpleFeatures {
    my ($self) = @_;

    $self->{'_SimpleFeature_list'} = [];
}

sub add_SimpleFeatures {
    my $self = shift;

    push @{ $self->{'_SimpleFeature_list'} }, @_;
    $self->{'_SimpleFeatures_are_sorted'} = 0;
}

sub set_SimpleFeature_list {
    my $self = shift;

    $self->clear_SimpleFeatures;
    $self->add_SimpleFeatures( @_ );
}

sub get_all_SimpleFeatures {
    my ($self) = @_;

    my $feat_list = $self->{'_SimpleFeature_list'}
      or return;
    
    # Set seq_name in features to our own
    if (my $name = $self->name) {
        foreach my $feat (@$feat_list) {
            $feat->seq_name($name);
        }
    }

    # Attach genomic sequence object to features
    if (my $seq = $self->Sequence) {
        foreach my $feat (@$feat_list) {
            $feat->seq_Sequence($seq);
        }
    }

    unless ($self->{'_SimpleFeatures_are_sorted'}) {
        @$feat_list = sort {
            $a->seq_start <=> $b->seq_start
            || $a->seq_end <=> $b->seq_end
            || $a->method_name cmp $b->method_name
            || $a->score <=> $b->score
            || $a->seq_strand <=> $b->seq_strand
            || $a->text cmp $b->text
          } @$feat_list;
        $self->{'_SimpleFeatures_are_sorted'} = 1;
    }

    return @$feat_list;
}

sub filter_SimpleFeature_list_from_ace_handle {
    my ($self, $ace) = @_;

    my $coll = $self->MethodCollection
      or confess "No MethodCollection attached";

    # We are only interested in the "editable" features on the Assembly.
    my %mutable_method =
      map { lc $_->name, $_ } $coll->get_all_mutable_non_transcript_Methods;

    my $name = $self->name;
    my $seq  = $self->Sequence;
    $ace->raw_query("find Sequence $name");
    my $sf_list = $self->{'_SimpleFeature_list'} ||= [];
    foreach my $row ($ace->values_from_tag('Feature')) {
        my ($method_name, $start, $end, $score, $text) = @$row;
        my $method = $mutable_method{lc $method_name}
          or next;

        my $feat = Hum::Ace::SeqFeature::Simple->new;
        $feat->seq_Sequence($seq);
        $feat->seq_name($name);
        $feat->Method($method);
        if ($start <= $end) {
            $feat->seq_start($start);
            $feat->seq_end($end);
            $feat->seq_strand(1);
        }
        else {
            $feat->seq_start($end);
            $feat->seq_end($start);
            $feat->seq_strand(-1);
        }
        $feat->score($score);
        $feat->text($text);

        push @$sf_list, $feat;
    }
    #printf STDERR "Found %d editable SimpleFeatures\n", scalar @$sf_list;
}

sub ace_string {
    my ($self) = @_;
    
    my $name = $self->name;
    
    my $ace = qq{\nSequence "$name"\n};
    my $coll = $self->MethodCollection
      or confess "No MethodCollection attached";
    foreach my $method ($coll->get_all_mutable_non_transcript_Methods) {
        $ace .= sprintf qq{-D Feature "%s"\n}, $method->name;
    }
    
    $ace .= qq{\nSequence "$name"\n};
    
    foreach my $feat ($self->get_all_SimpleFeatures) {
        $ace .= $feat->ace_string;
    }
    
    return $ace;
}

sub zmap_SimpleFeature_xml {
    my ($self, $old) = @_;
    
    if ($old and $self == $old) {
        confess "Old and new assemblies are the same object!";
    }
    
    # If $old is supplied, we create the minimum update transaction.
    
    my %new_feat = map {$_->zmap_xml_feature_tag, 1} $self->get_all_SimpleFeatures;
    my %old_feat;
    if ($old) {
        %old_feat = map {$_->zmap_xml_feature_tag, 1} $old->get_all_SimpleFeatures;
    } else {
        %old_feat = ();
    }

    my( $del_xml, $cre_xml, @xml);
    foreach my $str (keys %old_feat) {
        # Delete if feature in old set is not in the new
        unless ($new_feat{$str}) {
            $del_xml .= $str;
        }
    }
    if ($del_xml) {
        push(@xml, $self->zmap_delete_xml_string($del_xml));
    }
        
    foreach my $str (keys %new_feat) {
        # Create if feature in new set is not in the old
        unless ($old_feat{$str}) {
            $cre_xml .= $str;
        }
    }
    if ($cre_xml) {
        push(@xml, $self->zmap_create_xml_string($cre_xml));
    }
    
    return @xml;
}

sub zmap_delete_xml_string {
    my ($self, $xml) = @_;
    
    return qq{<zmap action="delete_feature">\n}
      . qq{\t<featureset>\n}
      . qq{\t\t} . $xml
      . qq{\t</featureset>\n}
      . qq{</zmap>\n};
}

sub zmap_create_xml_string {
    my ($self, $xml) = @_;
    
    return qq{<zmap action="create_feature">\n}
      . qq{\t<featureset>\n}
      . qq{\t\t} . $xml
      . qq{\t</featureset>\n}
      . qq{</zmap>\n};
}


sub express_data_fetch {
    my( $self, $ace ) = @_;
    
    # Get Methods first, since they are used by other objects
    $self->store_MethodCollection_from_ace_handle($ace);
    my %name_method = map {$_->name, $_} $self->MethodCollection->get_all_transcript_Methods;

    my $name = $self->name;
    
    # To save memory we only store the DNA from this top level sequence object.
    $self->store_Sequence_from_ace_handle($ace);
    
    # These raw_queries are much faster than
    # fetching the whole Genome_Sequence object!
    $ace->raw_query("find Sequence $name");

    if (my ($species) = $ace->values_from_tag('Species')) {
        $self->species($species->[0]);
    }
    if (my ($assembly_name) = $ace->values_from_tag('Assembly_name')) {
        $self->assembly_name($assembly_name->[0]);
    }

    # The SimpleFeatures we are intersted in (polyA etc...)
    # are only present on the top level assembly object.
    $self->filter_SimpleFeature_list_from_ace_handle($ace);

    my( $err, %name_locus );
    foreach my $sub_txt ($ace->values_from_tag('Subsequence')) {
        eval{
            my($name, $start, $end) = @$sub_txt;
            my $t_seq = $ace->fetch(Sequence => $name)
                or die "No such Subsequence '$name'\n";
            $name =~ s/^em://i;
            my $sub = Hum::Ace::SubSeq
                ->new_from_name_start_end_transcript_seq(
                    $name, $start, $end, $t_seq,
                    );
            $sub->clone_Sequence($self->Sequence);

            # Flag that the sequence is in the db
            $sub->is_archival(1);

            # Is there a Method attached?
            if (my $meth_tag = $t_seq->at('Method[1]')) {
                my $meth_name = $meth_tag->name;
                # We treat "GD:", "MPI:" etc... prefixed methods
                # the same as the non-prefixed methods.
                $meth_name =~ s/^[^:]+://;
                my $meth = $name_method{$meth_name};
                unless ($meth) {
                    confess "No transcript Method called '$meth_name'";
                }
                $sub->GeneMethod($meth);
            }

            # Is there a Locus attached?
            if (my $locus_tag = $t_seq->at('Visible.Locus[1]')) {
                my $locus_name = $locus_tag->name;
                my $locus = $name_locus{$locus_name};
                unless ($locus) {
                    $locus = Hum::Ace::Locus->new_from_ace_tag($locus_tag);
                    $name_locus{$locus_name} = $locus;
                }
                $sub->Locus($locus);
            }

            $self->add_SubSeq($sub);
        };
        $err .= $@ if $@;
    }
    warn $err if $err;

    # Store the information from the clones
    $ace->raw_query("find Sequence $name");
    foreach my $frag ($ace->values_from_tag('AGP_Fragment')) {
        my ($clone_name, $start, $end) = @{$frag}[0,1,2];
        my $strand = 1;
        if ($start > $end) {
            ($start, $end) = ($end, $start);
            $strand = -1;
        }

        my $clone = Hum::Ace::Clone->new;
        $clone->name($clone_name);
        $clone->express_data_fetch($ace);
        $clone->assembly_start($start);
        $clone->assembly_end($end);
        $clone->assembly_strand($strand);
        
        $self->add_Clone($clone);
    }
}

sub store_MethodCollection_from_ace_handle {
    my ($self, $ace) = @_;
    
    my $coll = Hum::Ace::MethodCollection->new_from_ace_handle($ace);
    $coll->order_by_right_priority;
    $self->MethodCollection($coll);
}

sub store_Sequence_from_ace_handle {
    my( $self, $ace ) = @_;
    
    my $seq = $self->new_Sequence_from_ace_handle($ace);
    $self->Sequence($seq);
}

sub new_Sequence_from_ace_handle {
    my( $self, $ace ) = @_;
    
    my $name = $self->name;
    my $seq = Hum::Sequence::DNA->new;
    $seq->name($name);
    my ($dna_obj) = $ace->fetch(DNA => $name);
    if ($dna_obj) {
        my $dna_str = $dna_obj->fetch->at->name;
        #warn "Got DNA string ", length($dna_str), " long";
        $seq->sequence_string($dna_str);
    } else {
        my $genomic = $ace->fetch(Sequence => $name)
            or confess "Can't fetch Sequence '$name' : ", Ace->error;
        my $dna_str = $genomic->asDNA
            or confess "asDNA didn't fetch the DNA : ", Ace->error;
        $dna_str =~ s/^>.+//m
            or confess "Can't strip fasta header";
        $dna_str =~ s/\s+//g;
        
        ### Nasty hack sMap is putting dashes
        ### on the end of the sequence.
        $dna_str =~ s/[\s\-]+$//;
        
        $seq->sequence_string($dna_str);
        
        #use Hum::FastaFileIO;
        #my $debug = Hum::FastaFileIO->new_DNA_IO("> /tmp/spandit-debug.seq");
        #$debug->write_sequences($seq);
    }
    warn "Sequence '$name' is ", $seq->sequence_length, " long\n";
    return $seq;
}

sub add_Clone {
    my( $self, $clone ) = @_;
    
    #print STDERR "Adding: $self, $name, $start, $end\n";
    
    my $list = $self->{'_Clone_list'} ||= [];
    push @$list, $clone;
}

sub get_all_Clones {
    my ($self) = @_;
    
    my $list = $self->{'_Clone_list'} or return;
    return @$list;
}

sub get_Clone {
    my ($self, $clone_name) = @_;
    
    my $clone;
    foreach my $this ($self->get_all_Clones) {
        if ($this->name eq $clone_name) {
            $clone = $this;
            last;
        }
    }
    confess "Can't find clone '$clone_name' in list"
      unless $clone;
}

sub replace_Clone {
    my( $self, $clone ) = @_;
    
    my $name = $clone->name;
    my $clone_list = $self->{'_Clone_list'}
        or confess "No Clone list";
    for (my $i = 0; $i < @$clone_list; $i++) {
        my $this = $clone_list->[$i];
        if ($this->name eq $name) {
            splice(@$clone_list, $i, 1, $clone);
            return 1;
        }
    }
    confess "No such Clone '$name' to replace";
}

sub clone_name_overlapping {
    my( $self, $pos ) = @_;
    
    # print STDERR "Getting: $self, $pos\n";
    
    my $list = $self->{'_Clone_list'} or return;
    foreach my $clone (@$list) {
        if ($pos >= $clone->assembly_start and $pos <= $clone->assembly_end) {
            return $clone->clone_name;
        }
    }
}

sub generate_description_for_clone {
	my ( $self, $clone ) = @_;
	
	# set to true to generate a description that specifies if the 
	# clone contains a central part or the 5' or 3' end of partial 
	# loci - but note that this can only work if the current assembly 
	# happens to contain the remainder of the locus. Otherwise the 
	# description will (rather boringly) just state that the clone 
	# contains 'part of' the locus, but will at least be consistent!
	my $BE_CLEVER = 0;
	
	my $DEBUG = 0;
	
	my $locus_sub;
	
	foreach my $sub (sort { ace_sort($a->name, $b->name) } $self->get_all_SubSeqs) {
		next unless ($sub->Locus->is_truncated || $sub->GeneMethod->mutable);
        my $tsct_list = $locus_sub->{$sub->Locus->name} ||= [];
        push(@$tsct_list, $sub);
    }
	
	my $cstart = $clone->assembly_start;
	my $cend = $clone->assembly_end;
	
	print "clone: $cstart-$cend\n" if $DEBUG;
	
	my $final_line = 'Contains ';
	my @keywords;
	my $novel_gene_count = 0;
	my $part_novel_gene_count = 0;
	my @DEline;
	
	foreach my $loc_name (keys %$locus_sub) {
		
		print "checking next locus: $loc_name\n" if $DEBUG;
		
        my $tsct_list = $locus_sub->{$loc_name};
        my $locus = $tsct_list->[0]->Locus;
        my $lname = $locus->name;
        my $lstrand = $tsct_list->[0]->strand;
        
        # ignore loci with prefixes
        next if $lname =~ /^.+:/;
        
        my $desc = $locus->description;
        
        # ignore loci without descriptions
        next unless $desc;
        
        # ignore transposons
        next if $desc =~ /transposon/i;
        
        # identify the start and end of the locus
        my $lstart = $tsct_list->[0]->start;
        my $lend = $tsct_list->[0]->end;
        
        for my $tsct (@$tsct_list) {
        	my $start = $tsct->start;
        	my $end = $tsct->end;
        	$lstart = $start if $start < $lstart;
        	$lend = $end if $end > $lend;
        	die "mixed strands" if $tsct->strand != $lstrand;
        }
        print "locus: $lstart-$lend\n" if $DEBUG;
        
        # establish if any part of this locus lies on this clone
        my $line;
        
        my $partial_text = 'part of ';
        
        if ($lstart >= $cstart && $lend <= $cend) {
        	# this locus lies entirely within this clone
        	$line = '';
        }
        elsif ($lstart < $cstart && $lend > $cend) {
        	# a central part of the locus lies in this clone
        	$line = $BE_CLEVER ? 
        				'a central part of ' : 
        				$partial_text;
        }
        elsif ($lend >= $cstart && $lend <= $cend) {
        	# the end of this locus lies in this clone
        	$line = $BE_CLEVER ?
        				'the '.($lstrand == 1 ? "3'" : "5'").' end of ' :
        				$partial_text;
        }
        elsif ($lstart >= $cstart && $lstart <= $cend) {
        	# the start of this locus lies in this clone
        	$line = $BE_CLEVER ?
        				'the '.($lstrand == 1 ? "5'" : "3'").' end of ' :
        				$partial_text;
        }
        else {
        	# no part of this locus lies on this clone
        	next;
        }
        
        $line = $partial_text if $locus->is_truncated;
        
        $desc =~ s/\s+$//;
       
        if ($desc =~ /novel\s+(protein|transcript|gene)\s+similar/) {
            $line .= "a gene for a $desc";
            push @DEline, \$line;
        }
        elsif (($desc =~ /(novel protein|novel transcript|novel gene)/) ) {
            if ($desc =~ /(zgc:\d+)/) {
                $line .= "a gene for a novel protein ($1)";
                push @DEline, \$line;
            }
            else {
            	$line ? $part_novel_gene_count++ : $novel_gene_count++; 
            }
        }
        elsif ($desc =~ /pseudogene/) {
            $line .= "a $desc";
            push @DEline, \$line ;
        }
        elsif ($lname =~ $clone->accession) {
            $line .= "a gene for a $desc";
            push @DEline, \$line;
        }
        elsif ($lname !~ /-/) {
            $line .= "the $lname gene for $desc" ; 
            push @DEline,\$line ; 
            push @keywords, $locus;
        }
        else {
            $line .= "a gene for a $desc";
            push @DEline, \$line;
        }
        
        print "line: $line\n" if $DEBUG;
	}
	
	if ($novel_gene_count) {
        if ($novel_gene_count == 1) {
           	my $line = "a novel gene";
           	push @DEline, \$line;
       	}
       	else {
           	my $line = $novel_gene_count." novel genes";
           	push @DEline, \$line;
       	}
    }
    
    if ($part_novel_gene_count) {
        if ($part_novel_gene_count == 1) {
           	my $line = "part of a novel gene";
           	push @DEline, \$line;
       	}
       	else {
           	my $line = "parts of ".$novel_gene_count." novel genes";
           	push @DEline, \$line;
       	}
    }
	
	my $range = scalar @DEline; 
    return '' if ($range < 1);
    if ($range == 1) {
        $final_line .= ${$DEline[0]}.".";
    }
    elsif ($range == 2) {
        $final_line .= ${$DEline[0]}. " and ".${$DEline[1]}.".";
    }
    else {
        for (my $k = 0; $k < ($range - 2); $k++) {
            $final_line .= ${$DEline[$k]}.", ";
        }
        $final_line .= ${$DEline[$range -2]}." and ".${$DEline[$range-1]}.".";
    }
	
	print $final_line."\n" if $DEBUG;
	
	return $final_line;   
}

1;

__END__

=head1 NAME - Hum::Ace::Assembly

=head1 AUTHOR

James Gilbert B<email> jgrg@sanger.ac.uk

