
### Hum::Ace::Method

package Hum::Ace::Method;

use strict;
use Carp;
use Hum::Ace::Colors qw{ acename_to_webhex };

sub new {
    my( $pkg ) = @_;
    
    return bless {}, $pkg;
}

my @boolean_tags = qw{
    
    Has_parent
    Edit_score
    Edit_display_label
    Coding
    Allow_misalign
    
    };

sub new_from_name_AceText {
    my( $pkg, $name, $txt ) = @_;
    
    my $self = $pkg->new;
    $self->name($name);
    
    # True/false tags
    foreach my $tag (@boolean_tags) {
        my $method = lc $tag;
        if ($txt->count_tag($tag)) {
            $self->$method(1);
        }
    }
        
    # Methods with the same column_parent are put in the same column in the Zmap display
    if (my ($grp) = $txt->get_values('Column_parent')) {
        $self->column_parent($grp->[0]);
    }
    
    if (my ($name) = $txt->get_values('Style')) {
        $self->style_name($name->[0]);
    }
    
    # Correct length for feature
    if (my ($len) = $txt->get_values('Valid_length')) {
        $self->valid_length($len->[0]);
    }
    
    # Remarks, which are used to display a little more information
    # than the name alone in parts of otterlace and zmap.
    if (my ($rem) = $txt->get_values('Remark')) {
        $self->remark($rem->[0]);
    }
    
    return $self;
}

{
    my @boolean_methods = map lc, @boolean_tags;

    sub clone {
        my( $self ) = @_;

        my $new = ref($self)->new;

        foreach my $method (qw{
            name
            column_parent
            valid_length
            remark
            style_name
            },
            @boolean_methods,
        ) {
            $new->$method($self->$method());
        }

        # if (my $style = $self->Zmap_Style) {
        #     $new->Zmap_Style($style->clone);
        # }

        return $new;
    }
}

sub ace_string {
    my( $self ) = @_;
    
    my $name = $self->name;
    my $txt = Hum::Ace::AceText->new(qq{\nMethod : "$name"\n});
    
    if (my $group = $self->column_parent) {
        $txt->add_tag('Column_parent', $group);
    }
    
    if (my $sn = $self->style_name) {
        $txt->add_tag('Style', $sn);
    }

    foreach my $tag (@boolean_tags)
    {
        my $tag_method = lc $tag;
        $txt->add_tag($tag) if $self->$tag_method();
    }
        
    foreach my $tag (qw{
        Valid_length
        Remark
        })
    {
        my $tag_method = lc $tag;
        if (defined (my $val = $self->$tag_method())) {
            $txt->add_tag($tag, $val);
        }
    }
    
    return $txt->ace_string;
}

sub name {
    my( $self, $name ) = @_;
    
    if ($name) {
        $self->{'_name'} = $name;
    }
    return $self->{'_name'};
}

sub column_parent {
    my( $self, $column_parent ) = @_;
    
    if ($column_parent) {
        $self->{'_column_parent'} = $column_parent;
    }
    return $self->{'_column_parent'} || '';
}

sub get_all_child_Methods {
    my ($self) = @_;
    
    if (my $chld = $self->{'_column_children'}) {
        return @$chld;
    } else {
        return;
    }
}

sub add_child_Method {
    my ($self, $method) = @_;
    
    my $chld = $self->{'_column_children'} ||= [];
    push(@$chld, $method);
}

sub style_name {
    my $self = shift;
    
    if (@_) {
        $self->{'_style_name'} = shift;
    }
    if (my $style = $self->Zmap_Style) {
        my $name = $style->name
            or confess "Anonymous Zmap_Style object attached to Method";
        return $name;
    } else {
        return $self->{'_style_name'};
    }
}

sub Zmap_Style {
    my( $self, $Zmap_Style ) = @_;
    
    if ($Zmap_Style) {
        $self->{'_Zmap_Style'} = $Zmap_Style;
        $self->style_name(undef);
    }
    return $self->{'_Zmap_Style'};
}

sub is_transcript {
    my ($self) = @_;
    
    if (my $style = $self->Zmap_Style) {
        # printf STDERR "Inherited mode of Zmap_Style '%s' is '%s'\n",
        #     $style->name, $style->inherited_mode;
        return $style->inherited_mode eq 'Transcript';
    } else {
        # printf STDERR "No Zmap_Style attached to method '%s'\n", $self->name;
        return 0;
    }
}

sub remark {
    my( $self, $remark ) = @_;
    
    if ($remark) {
        $self->{'_remark'} = $remark;
    }
    return $self->{'_remark'};
}

sub mutable {
    my( $self, $flag ) = @_;
    
    # True if the attached Style is or descends from a "curated_*" style
    if (my $style = $self->Zmap_Style) {
        return $style->is_mutable;
    } else {
        return 0;
    }
}

sub coding {
    my( $self, $coding ) = @_;
    
    if ($coding) {
        $self->{'_coding'} = $coding;
    }
    return $self->{'_coding'};
}

# Controls nesting of transcript sub-types in ExonCanvas menu
sub has_parent {
    my( $self, $flag ) = @_;
    
    if (defined $flag) {
        $self->{'_has_parent'} = $flag ? 1 : 0;
    }
    return $self->{'_has_parent'};
}

# Next three methods are used by GenomicFeatures window

sub valid_length {
    my( $self, $valid_length ) = @_;
    
    if ($valid_length) {
        $self->{'_valid_length'} = $valid_length;
    }
    return $self->{'_valid_length'};
}

sub edit_score {
    my( $self, $flag ) = @_;
    
    if (defined $flag) {
        $self->{'_edit_score'} = $flag ? 1 : 0;
    }
    return $self->{'_edit_score'};
}

sub edit_display_label {
    my( $self, $flag ) = @_;
    
    if (defined $flag) {
        $self->{'_edit_display_label'} = $flag ? 1 : 0;
    }
    return $self->{'_edit_display_label'};
}

sub allow_misalign {
    my( $self, $flag ) = @_;
    
    if (defined $flag) {
        $self->{'_allow_misalign'} = $flag ? 1 : 0;
    }
    return $self->{'_allow_misalign'};
}

1;

__END__

=head1 NAME - Hum::Ace::Method

=head1 AUTHOR

James Gilbert B<email> jgrg@sanger.ac.uk

