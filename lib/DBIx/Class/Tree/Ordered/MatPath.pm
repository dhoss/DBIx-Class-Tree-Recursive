package DBIx::Class::Tree::Ordered::MatPath;
 
use warnings;
use strict;
 
use parent qw/DBIx::Class::Ordered/;
 
sub parent_column { shift->grouping_column (@_) }
sub path_column   { shift->position_column (@_) }
 
__PACKAGE__->mk_classdata ('escaped_separator');
__PACKAGE__->mk_classdata (path_separator => '.');
sub set_inherited {
  my $self = shift;
  $self->escaped_separator (defined $_[1] ? quotemeta($_[1]) : undef)
    if ($_[0] eq 'path_separator');
  $self->next::method (@_);
}
 
sub all_parents {
  my $self = shift;
 
  my $path_col = $self->path_column;
  my $sep = $self->path_separator;
  my $esep = $self->escaped_separator;
 
  my @path_parts = split (/$esep/, $self->get_column($path_col));
 
  pop @path_parts; # don't need ourselves
  for my $i (1 .. $#path_parts) {
    $path_parts[$i] = join ($sep, @path_parts[$i-1, $i]);
  }
  return $self->result_source->resultset->search({
    $path_col => { -in => \@path_parts },
  });
}
 
sub all_children {
  my $self = shift;
 
  my $path_col = $self->path_column;
  my $sep = $self->path_separator;
  my $path = $self->get_column($path_col);
  $path = '' if $path eq $sep; 
  return $self->result_source->resultset->search({
    '-and' => [
       { "me.$path_col" => { '!=', $self->get_column($path_col) } },
       { "me.$path_col" => { -like => join ($sep, $path,'%') } },
    ]
  });
}
 
sub parent {
  my $self = shift;
  my $pcol = $self->parent_column;
  if ( $pcol == undef ) {
      return undef;
  } else {
      return $pcol;
  }
}
 
sub _position_from_value {
  my ($self, $val) = @_;
 
  my $esep = $self->escaped_separator;
  return (split /$esep/, $val)[-1];
}
 
sub _position_value {
  my ($self, $pos) = @_;
 
  my $p = $self->parent
    or return $pos;
 
  return join ($self->path_separator, $p->get_column($p->path_column), $pos);
}
 
sub _initial_position_value {
  my $self = shift;
  return $self->next::method (@_) if @_;
 
  my $init = $self->next::method;
 
  my $p = $self->parent
    or return $init;
 
  return join ($p->path_separator, $p->get_column($p->path_column), $init );
}
 
sub _next_position_value {
  my ($self, $val) = @_;
 
  my $sep = $self->path_separator;
  my $esep = $self->escaped_separator;
  my @parts = split (/$esep/, $val);
  $parts[-1]++;
  return join ($sep, @parts);
}
 
sub _shift_siblings {
  my ($self, $direction, @between) = @_;
  return 0 unless $direction;
 
  my $path_column = $self->path_column;
  my $sep = $self->path_separator;
  my $esep = $self->escaped_separator;
 
  my ($shift, $ord);
  if ($direction < 0) {
    $shift = -1;
    $ord = 'asc';
  }
  else {
    $shift = 1;
    $ord = 'desc';
  }
 
  my $shift_rs = $self->_group_rs->search ({ $path_column => { -between => \@between } });
 
  for my $sibling ($shift_rs->search ({}, { order_by => { "-$ord", $path_column }})->all ) {
    my $old_pos = $sibling->get_column($path_column);
 
    my @parts = split (/$esep/, $old_pos);
    $parts[-1] += $shift;
    my $new_pos = join ($sep, @parts);
 
    $sibling->_ordered_internal_update ({$path_column => $new_pos });
 
    # re-number children too
    my $children = $self->result_source->resultset->search ({$path_column => { -like => "$old_pos$sep%" } });
    for my $child ($children->all) {
      my $cpath = $child->get_column($path_column);
      $cpath =~ s/^$old_pos/$new_pos/;
      $child->_ordered_internal_update ({$path_column => $cpath });
    }
  }
}
 
## direct children:
## all_children->search (... -not_like => 'path $sep % $sep %
sub direct_children {
    my $self = shift;

	my $path_col = $self->path_column;
	my $sep = $self->path_separator;

    my $match = join($sep, $self->get_column($path_col), '%', $sep,'%');
    $match =~ s/($sep)+/$sep/g;

	return $self->all_children->search({
	    "me.$path_col" => { '-not_like' => $match }
    });
}


1;
