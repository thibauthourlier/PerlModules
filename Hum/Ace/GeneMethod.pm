
### Hum::Ace::GeneMethod

package Hum::Ace::GeneMethod;

use strict;
use Carp;
use Hum::Ace::Colors;

sub new {
    my( $pkg ) = @_;
    
    return bless {}, $pkg;
}

sub new_from_ace_tag {
    my( $pkg, $tag ) = @_;
    
    my $self = $pkg->new;
    $self->process_ace_method($tag->fetch);
    return $self;
}

sub new_from_ace {
    my( $pkg, $ace ) = @_;
    
    my $self = $pkg->new;
    $self->process_ace_method($ace);
    return $self;
}

sub process_ace_method {
    my( $self, $ace ) = @_;
    
    $self->name($ace->name);
    my $color = $ace->at('Display.Colour[1]')
        or confess "No color";
    $self->color($color->name);
    if (my $cds_color = $ace->at('Display.CDS_Colour[1]')) {
        $self->cds_color($cds_color->name);
    }
}

sub name {
    my( $self, $name ) = @_;
    
    if ($name) {
        $self->{'_name'} = $name;
    }
    return $self->{'_name'};
}

sub color {
    my( $self, $color ) = @_;
    
    if ($color) {
        $self->{'_color'} = $color;
    }
    return $self->{'_color'};
}

sub cds_color {
    my( $self, $cds_color ) = @_;
    
    if ($cds_color) {
        $self->{'_cds_color'} = $cds_color;
    }
    return $self->{'_cds_color'};
}

sub hex_color {
    my( $self ) = @_;
    
    my $color = $self->color;
    return Hum::Ace::Colors::acename_to_webhex($color);
}

sub hex_cds_color {
    my( $self ) = @_;
    
    my $color = $self->cds_color;
    return Hum::Ace::Colors::acename_to_webhex($color);
}

sub is_mutable {
    my( $self, $flag ) = @_;
    
    if (defined $flag) {
        my $value = $self->{'_is_mutable'};
        if (defined $value) {
            confess "attempt to change read-only property";
        } else {
            $self->{'_is_mutable'} = $flag ? 1 : 0;
        }
    }
    return $self->{'_is_mutable'};
}

sub is_coding {
    my( $self, $flag ) = @_;
    
    if (defined $flag) {
        $self->{'_is_coding'} = $flag ? 1 : 0;
    } else {
        if (defined($flag = $self->{'_is_coding'})) {
            return $flag;
        } else {
            return $self->name =~ /(pseudo|mrna)/i ? 0 : 1;
        }
    }
}

1;

__END__

=head1 NAME - Hum::Ace::GeneMethod

=head1 AUTHOR

James Gilbert B<email> jgrg@sanger.ac.uk

