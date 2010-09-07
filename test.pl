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

#print "Idiot's parent:" . $rs->find ({name => 'rookie 1.2'})->get_parent;
#print "\n";

print "How many parents does the idiot have: " . $rs->find ({name => 'rookie 1.2'})->all_parents->count;
print "\n";

print "How many children does the chief have besides the retard: " . $chief->direct_children->count;
print "\n";
print "Direct child of the chief: " . $chief->direct_children->first->name;
print "\n";
print "Direct child of first subordinate: " . $rs->find ({name => 'subordinate 1'})->direct_children->first->name;
print "\n";
sub dump_rs {
  my ($rs, $desc) = @_;
  
  print "-------\n$desc\n-------\n";
  print join ("\t\t", qw/ id name parent path/, "\n");
  for ($rs->search({}, { columns => [qw/ id name parent_id path/], order_by => 'parent_id DESC' })->cursor->all) {
    print join ("\t", map { defined $_ ? $_ : 'NULL' } @$_, "\n");
  }

  print "\n\n";
}