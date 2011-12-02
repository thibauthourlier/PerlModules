
### Hum::SequenceOverlap

package Hum::Cigar;

use strict;
use warnings;
use Carp;

sub new {
    my ($pkg, $cigar) = @_;

    return bless {CIGAR=>$cigar}, $pkg;
}

sub cigar_string {
	my ($self, $cigar_string) = @_;
	
	if($cigar_string) {
		$self->{CIGAR} = $cigar_string;
	}
	
	return $self->{CIGAR};
}

sub match_length {
	my ($self) = @_;
	
	if(!exists($self->{MATCH_LENGTH})) {
		
		my $match_length;
		foreach my $cigar_part ($self->cigar_parts) {
			if($cigar_part =~ /(.*)M$/) {
				my $count = $1;
				if(length($count) == 0) {
					$count = 1;
				}
				$match_length += $count;
			}
		}
		
		$self->{MATCH_LENGTH} = $match_length;
	}
	
	return($self->{MATCH_LENGTH});
}

sub percent_deletion {
	my ($self) = @_;
	
	my $count_D = 0;
	my $cigar_string = $self->cigar_string;
    while ($cigar_string =~ /(\d*)D/g) {
        $count_D += $1 || 1;
    }
    my $percent_deletion = 100 * ($count_D / $self->match_length);
	
	return $percent_deletion;
}

sub percent_insertion {
	my ($self) = @_;
	
	my $count_I = 0;
	my $cigar_string = $self->cigar_string;
    while ($cigar_string =~ /(\d*)I/g) {
        $count_I += $1 || 1;
    }
    my $percent_insertion = 100 * ($count_I / $self->match_length);
	
	return $percent_insertion;
}

sub reverse {
	my ($self) = @_;
	
	my @cigar_parts = $self->cigar_parts;
	@cigar_parts = reverse @cigar_parts;
	my $reverse_cigar = join("", @cigar_parts);
	
	$self->cigar_string($reverse_cigar);
	return $reverse_cigar;
}

sub complement {
	my ($self) = @_;

	my $cigar_string = $self->cigar_string;
	$cigar_string =~ s/I/X/g;
	$cigar_string =~ s/D/I/g;
	$cigar_string =~ s/X/D/g;

	$self->cigar_string($cigar_string);
	return $cigar_string;
}

sub cigar_parts {
	my ($self) = @_;
	return split(/(?<=[A-Z])/, $self->cigar_string);
}

sub clean {
	my ($self) = @_;
	
	my @cigar_parts = $self->cigar_parts;
	foreach my $cigar_part (@cigar_parts) {
		$cigar_part =~ s/^1(?<=[DMI])//;
	}
	my $clean_cigar = join("", @cigar_parts);
	
	$self->cigar_string($clean_cigar);
	return $clean_cigar;
}

1;

__END__

=head1 NAME - Hum::Cigar

=head1 AUTHOR

James Torrance B<email> jt8@sanger.ac.uk
