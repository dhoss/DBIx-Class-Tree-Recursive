use strict;
use warnings;
use Test::More;
use lib "t/lib";
use Schema;
my $schema = Schema->connect ('dbi:SQLite::memory:');

$schema->deploy;

my $rs = $schema->resultset ('Test');

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

print "How many children does the chief have besides the retard: " . $chief->get_direct_children->count;
print "\n";
print "Direct child of the chief: " . $chief->get_immediate_child->name;
print "\n";
print "Direct child of first subordinate: " . $rs->find ({name => 'subordinate 1'})->get_immediate_child->name;
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