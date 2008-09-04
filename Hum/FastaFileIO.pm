
### Hum::FastaFileIO

package Hum::FastaFileIO;

use strict;
use Carp;
use Symbol ();

use Hum::Sequence;
use Hum::Sequence::DNA;
use Hum::Sequence::Peptide;

sub new {
    my( $pkg, $file ) = @_;

    my $ffio = bless {}, $pkg;
    $ffio->file_handle($file) if $file;
    return $ffio;
}

sub new_String_IO {
    my( $pkg, $string ) = @_;

    my $ffio = bless {}, $pkg;
    $ffio->string_to_file_handle($string) if $string;
    return $ffio;
}

sub new_DNA_IO {
    my( $pkg, $file ) = @_;

    my $ffio = $pkg->new($file);
    $ffio->sequence_class('Hum::Sequence::DNA');
    return $ffio;
}

sub new_DNA_Quality_IO {
    my( $pkg, $file, $quality_file ) = @_;

    unless ($quality_file) {
        if (ref($file)) {
            confess "Can't auto generate quality file name from '$file'";
        } else {
            $quality_file = "$file.qual";
        }
    }

    my $ffio = $pkg->new_DNA_IO($file);
    $ffio->sequence_class('Hum::Sequence::DNA');

    $ffio->quality_file_handle($quality_file);

    return $ffio;
}

sub new_Peptide_IO {
    my( $pkg, $file ) = @_;

    my $ffio = $pkg->new($file);
    $ffio->sequence_class('Hum::Sequence::Peptide');
    return $ffio;
}

sub sequence_class {
    my( $ffio, $sequence_class ) = @_;

    if ($sequence_class) {
        $ffio->{'_sequence_class'} = $sequence_class;
    }
    return $ffio->{'_sequence_class'} || 'Hum::Sequence';
}

sub _next_line {
    my( $ffio ) = @_;

    if (my $line = $ffio->{'_last_line'}) {
        $ffio->{'_last_line'} = undef;
        return $line;
    } else {
        my $fh = $ffio->{'_file_handle'} || return;
        if ($line = <$fh>) {
            return $line;
        } else {
            $ffio->{'_file_handle'} = undef;
            return;
        }
    }
}

sub _push_back {
    my( $ffio, $line ) = @_;

    $ffio->{'_last_line'} = $line;
}

sub _last_quality_line {
    my( $ffio, $_last_quality_line ) = @_;

    if ($_last_quality_line) {
        $ffio->{'__last_quality_line'} = $_last_quality_line;
    } else {
        my $last = $ffio->{'__last_quality_line'};
        $ffio->{'__last_quality_line'} = undef;
        return $last;
    }
}

sub file_handle {
    my( $ffio, $file ) = @_;

    if ($file) {
        if (ref($file) eq 'GLOB') {
            $ffio->{'_file_handle'} = $file;
        } else {
            my $fh = Symbol::gensym();
            open $fh, $file or confess "Can't open file '$file' : $!";
            $ffio->{'_file_handle'} = $fh;
        }
    }
    return $ffio->{'_file_handle'};
}

sub string_to_file_handle {
    my( $ffio, $string ) = @_;

    if ($string) {
    	my $fh = Symbol::gensym();
    	open $fh,qq{ echo "$string" | };
    	$ffio->{'_file_handle'} = $fh;
    }
    return $ffio->{'_file_handle'};
}

sub quality_file_handle {
    my( $ffio, $file ) = @_;

    if ($file) {
        if (ref($file) eq 'GLOB') {
            $ffio->{'_quality_file_handle'} = $file;
        } else {
            my $fh = Symbol::gensym();
            open $fh, $file or confess "Can't open file '$file' : $!";
            $ffio->{'_quality_file_handle'} = $fh;
        }
    }
    return $ffio->{'_quality_file_handle'};
}

sub read_all_sequences {
    my( $ffio ) = @_;

    my( @all_seq );
    while (my $seq = $ffio->read_one_sequence) {
        push(@all_seq, $seq);
    }
    return @all_seq;
}

sub read_one_sequence {
    my( $ffio ) = @_;

    local $/ = "\n";

    my $class = $ffio->sequence_class;

    my $seq_string = '';
    my( $seq_obj );
    while ($_ = $ffio->_next_line) {
        if (my ($name, $desc) = /^>\s*(\S+)\s*(.*)/) {
            #warn "Got '$name'\n";
            if ($seq_obj) {
                $ffio->_push_back($_);
                last;
            } else {
                $seq_obj = $class->new();
                $seq_obj->name($name);
                $seq_obj->description($desc) if $desc;
            }
        } else {
            chomp;
            $seq_string .= $_;
        }
    }
    return unless $seq_obj;
    $seq_obj->sequence_string($seq_string);

    # Read quality values if we've got a handle to a quality file
    if ($ffio->quality_file_handle) {
        $ffio->_add_quality_string($seq_obj);
    }

    return $seq_obj;
}

sub _add_quality_string {
    my( $ffio, $seq_obj ) = @_;

    my $name = $seq_obj->name;
    my $qfh = $ffio->quality_file_handle
        or confess "No quality file handle";

    my $first_line = $ffio->_last_quality_line || <$qfh>;
    my ($q_name) = $first_line =~ /^>(\S+)/
        or die "Invalid first line '$first_line'";
    confess "Name in quality file '$q_name' doesn't match name in fasta file '$name'"
        unless $q_name eq $name;

    my $qual_string = '';
    while (<$qfh>) {
        if (/^>/) {
            $ffio->_last_quality_line($_);
            last;
        } else {
            $qual_string .= pack 'C*', split;
        }
    }
    $seq_obj->quality_string($qual_string);
}

sub write_sequences {
    my( $ffio, @all_seq ) = @_;

    my $fh  = $ffio->file_handle;
    my $qfh = $ffio->quality_file_handle;
    foreach my $seq_obj (@all_seq) {
        print $fh $seq_obj->fasta_string
            or confess "Error printing fasta : $!";

        if ($qfh) {
            print $qfh $seq_obj->fasta_quality_string
                or confess "Error printing fasta : $!";
        }
    }
}


1;

__END__

=head1 NAME - Hum::FastaFileIO

=head1 AUTHOR

James Gilbert B<email> jgrg@sanger.ac.uk

