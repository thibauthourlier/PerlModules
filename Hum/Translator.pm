
### Hum::Translator

package Hum::Translator;

use strict;
use Carp;

sub new {
    my( $pkg ) = @_;
    
    return bless {}, $pkg;
}

sub translate {
    my( $self, $seq ) = @_;
    
    my $is_seq = 0;
    eval{
        $is_seq = $seq->isa('Hum::Sequence');
    }
    unless ($is_seq) {
        confess "Expecting a 'Hum::Sequence' object, but got '$seq'";
    }
    
    my $seq_str = lc $seq->sequence_string;
    my $codon_table = $self->codon_table
        or confess "Go no codon table";
    my $unknown_amino_acid = $self->unknown_amino_acid;
    my $pep_str = '';
    while ($seq_str =~ /(...)/g) {
        $pep_str .= $condon_table->{$1} || $unknown_amino_acid;
    }
    return $pep_str;
}

sub unknown_amino_acid {
    my( $self, $unk ) = @_;
    
    if ($unk) {
        $self->{'_unknown_amino_acid'} = $unk;
    }
    return $self->{'_unknown_amino_acid'} || 'X';
}

{
    my $std = {

        'tca' => 'S',    # Serine
        'tcc' => 'S',    # Serine
        'tcg' => 'S',    # Serine
        'tct' => 'S',    # Serine

        'ttc' => 'F',    # Phenylalanine
        'ttt' => 'F',    # Phenylalanine
        'tta' => 'L',    # Leucine
        'ttg' => 'L',    # Leucine

        'tac' => 'Y',    # Tyrosine
        'tat' => 'Y',    # Tyrosine
        'taa' => '*',    # Stop
        'tag' => '*',    # Stop

        'tgc' => 'C',    # Cysteine
        'tgt' => 'C',    # Cysteine
        'tga' => '*',    # Stop
        'tgg' => 'W',    # Tryptophan

        'cta' => 'L',    # Leucine
        'ctc' => 'L',    # Leucine
        'ctg' => 'L',    # Leucine
        'ctt' => 'L',    # Leucine

        'cca' => 'P',    # Proline
        'ccc' => 'P',    # Proline
        'ccg' => 'P',    # Proline
        'cct' => 'P',    # Proline

        'cac' => 'H',    # Histidine
        'cat' => 'H',    # Histidine
        'caa' => 'Q',    # Glutamine
        'cag' => 'Q',    # Glutamine

        'cga' => 'R',    # Arginine
        'cgc' => 'R',    # Arginine
        'cgg' => 'R',    # Arginine
        'cgt' => 'R',    # Arginine

        'ata' => 'I',    # Isoleucine
        'atc' => 'I',    # Isoleucine
        'att' => 'I',    # Isoleucine
        'atg' => 'M',    # Methionine

        'aca' => 'T',    # Threonine
        'acc' => 'T',    # Threonine
        'acg' => 'T',    # Threonine
        'act' => 'T',    # Threonine

        'aac' => 'N',    # Asparagine
        'aat' => 'N',    # Asparagine
        'aaa' => 'K',    # Lysine
        'aag' => 'K',    # Lysine

        'agc' => 'S',    # Serine
        'agt' => 'S',    # Serine
        'aga' => 'R',    # Arginine
        'agg' => 'R',    # Arginine

        'gta' => 'V',    # Valine
        'gtc' => 'V',    # Valine
        'gtg' => 'V',    # Valine
        'gtt' => 'V',    # Valine

        'gca' => 'A',    # Alanine
        'gcc' => 'A',    # Alanine
        'gcg' => 'A',    # Alanine
        'gct' => 'A',    # Alanine

        'gac' => 'D',    # Aspartic Acid
        'gat' => 'D',    # Aspartic Acid
        'gaa' => 'E',    # Glutamic Acid
        'gag' => 'E',    # Glutamic Acid

        'gga' => 'G',    # Glycine
        'ggc' => 'G',    # Glycine
        'ggg' => 'G',    # Glycine
        'ggt' => 'G',    # Glycine

        };
    
    # This is in a method so that we can choose
    # other translation tables in the future
    sub codon_table {
        return $std;
    }
}

1;

__END__

=head1 NAME - Hum::Translator

=head1 AUTHOR

James Gilbert B<email> jgrg@sanger.ac.uk

