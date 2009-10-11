#!/usr/bin/perl

package S::T;

use warnings;
use strict;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components (qw/Ordered/);

__PACKAGE__->table ('nested');
__PACKAGE__->add_columns (
  id => { data_type => 'int', is_auto_increment => 1 },
  name => { data_type => 'varchar' },
  parent_id => { data_type => 'int', is_nullable => 1 },
  path => { data_type => 'varchar' },
);

__PACKAGE__->set_primary_key ('id');

__PACKAGE__->has_many ('children', __PACKAGE__, 'parent_id');
__PACKAGE__->belongs_to ('parent', __PACKAGE__, 'parent_id');

__PACKAGE__->position_column ('path');
__PACKAGE__->grouping_column ('parent_id');
__PACKAGE__->mk_classdata( 'separator_value' => '.' );
sub all_parents {
  my $self = shift;
  my $pos_col = $self->position_column;
  my @path_parts = split (/\./, $self->get_column($pos_col));
  pop @path_parts; # don't need ourselves
  for my $i (1 .. $#path_parts) {
    $path_parts[$i] = join ('.', @path_parts[$i-1, $i]);
  }
  return $self->result_source->resultset->search({
    $pos_col => { -in => \@path_parts },
  });
}

sub all_children {
  my $self = shift;
  my $pos_col = $self->position_column;
  my $pos_val = $self->get_column($pos_col);
  return $self->result_source->resultset->search({
    $pos_col => { -like => "$pos_val.%" },
  });
}

sub _position {
  my $self = shift;
  return $self->previous_siblings->count + 1;
}

sub _position_from_value {
  my ($self, $val) = @_;

  return 0 unless defined $val;

  return $self -> _group_rs
               -> search({ $self->position_column => { '<=', $val } })
               -> count
}

sub _position_value {
  my ($self, $pos) = @_;

  my $position_column = $self->position_column;

  my $cnt = $self->_group_rs->count;
  $pos = $cnt if $pos > $cnt;

  my $v = $self-> _group_rs
               -> search({}, { order_by => $position_column })
               -> slice ( $pos - 1)
               -> single
               -> get_column ($position_column);

  return $v;
}

sub _initial_position_value {
  my $self = shift;
  my $p = $self->parent
    or return 1;

  return join ('.', $p->get_column($p->position_column), 1 );
}

sub _next_position_value {
  my ($self, $val) = @_;

  my @parts = split (/\./, $val);
  $parts[-1]++;
  return join ('.', @parts);
}

sub _shift_siblings {
    my ($self, $direction, @between) = @_;
    return 0 unless $direction;

    my $position_column = $self->position_column;

    my ($shift, $ord);
    if ($direction < 0) {
        $shift = -1;
        $ord = 'asc';
    }
    else {
        $shift = 1;
        $ord = 'desc';
    }

    my $shift_rs = $self->_group_rs-> search ({ $position_column => { -between => \@between } });

    for my $sibling ($shift_rs->search ({}, { order_by => { "-$ord", $position_column }})->all ) {
      my $old_pos = $sibling->get_column($position_column);

      my @parts = split (/\./, $old_pos);
      $parts[-1] += $shift;
      my $new_pos = join ('.', @parts);

      $sibling->_ordered_internal_update ({$position_column => $new_pos });

      my $children = $self->result_source->resultset->search ({$position_column => { -like => "$old_pos.%" } });

      # re-number children too
      for my $child ($children->all) {
        my $cpos = $child->get_column($position_column);
        $cpos =~ s/^$old_pos/$new_pos/;
        $child->_ordered_internal_update ({$position_column => $cpos });
      }
    }
}

package S;

use warnings;
use strict;

use base qw/DBIx::Class::Schema/;

__PACKAGE__->load_classes qw/T/;


package x;

use warnings;
use strict;

my $schema = S->connect ('dbi:SQLite::memory:');

$schema->deploy;

my $rs = $schema->resultset ('T');

my $chief = $rs->create ({
  name => 'grand chief',
  children => [
    {
      name => 'subordinate 1',
      children => [
        map { { name => 'rookie 1.' . $_ } } qw/1 2 3/,
      ],
    },
    {
      name => 'subordinate 2',
      children => [
        map { { name => 'rookie 2.' . $_ } } qw/1 2/,
      ],
    },
  ]
});

dump_rs ($rs, 'initial state');

$rs->find ({name => 'rookie 1.2'})->update ({ parent_id => $chief->id });
dump_rs ($rs, 'promote a rookie to a subordinate');

$rs->find ({name => 'rookie 1.2'})->move_to(1);
dump_rs ($rs, 'make this same rookie 1st subordinate');

$rs->find ({name => 'rookie 1.2'})->move_to_group(undef, 1);
dump_rs ($rs, 'damn he is good - promote him to FIRST chief (this time use move_to_group)');

$rs->find ({name => 'rookie 1.2'})->move_to(2);
dump_rs ($rs, 'not that good - make 2nd chief');

my $sub2id = $rs->find ({name => 'subordinate 2'})->id;

$rs->find ({name => 'rookie 1.2'})->move_to_group($sub2id);
dump_rs ($rs, 'This guy is retarded, demote to last subordinate of 2nd subordinate');

print "How many parents does the idiot have: " . $rs->find ({name => 'rookie 1.2'})->all_parents->count;
print "\n";

print "How many children does the chief have besides the retard: " . $chief->all_children
    ->search({ name => { '!=', 'rookie 1.2' }})->count;
print "\n";


sub dump_rs {
  my ($rs, $desc) = @_;

  print "-------\n$desc\n-------\n";
  print join ("\t", qw/id unit_name parent path/, "\n");
  for ($rs->cursor->all) {
    print join ("\t", map { defined $_ ? $_ : 'NULL' } @$_, "\n");
  }

  print "\n\n";
}