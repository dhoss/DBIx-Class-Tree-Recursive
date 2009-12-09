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

ok ( check_rs( $rs, [undef, 1] ), "Initial state" );
$rs->find ({name => 'rookie 1.2'})->update ({ parent_id => $chief->id });
ok( check_rs ($rs, [2, 1.1.1]), 'promote a rookie to a subordinate' );

#$rs->find ({name => 'rookie 1.2'})->move_to(1);
#dump_rs ($rs, 'make this same rookie 1st subordinate');

#$rs->find ({name => 'rookie 1.2'})->move_to_group(undef, 1);
#dump_rs ($rs, 'damn he is good - promote him to FIRST chief (this time use move_to_group)');

#$rs->find ({name => 'rookie 1.2'})->move_to(2);
#dump_rs ($rs, 'not that good - make 2nd chief');

#my $sub2id = $rs->find ({name => 'subordinate 2'})->id;

#$rs->find ({name => 'rookie 1.2'})->move_to_group($sub2id);
#dump_rs ($rs, 'This guy is retarded, demote to last subordinate of 2nd subordinate');
## need to check positions of parents and children somehow.
##01:55 <@ribasushi> write a function which will take an arrayref of 
##                   parent/position pairs
##01:55 <@ribasushi> and compare it to the current resultset
##01:55 < dhoss> oh
##01:55 < dhoss> thinking too hard.
##01:55 <@ribasushi> and in the tests supply the arrayref of what you expect to 
##                   see in the table
##01:56 <@ribasushi> always have the rs ordered by the autoinc id (so you don't 
 ##                  get flux in the rows)
##01:56 <@ribasushi> done
sub check_rs {
	my ($rs, $expected_position_pairs) = @_;
	#$rs->reset;
	my $expected_parent   = $expected_position_pairs->[0] || "none";
	my $expected_position = $expected_position_pairs->[1];
	print "Expected Parent: $expected_parent\n";
	print "Expected Position: $expected_position\n";

	while ( my $row = $rs->next ) {
		print "Actual Parent: " . $row->get_parent->id . "\n";
		print "Actual Position: " .  $row->get_column($rs->result_class->path_column) . "\n";
		if ( 
			($expected_parent, $expected_position) ne 
			($row->get_parent->id,   $row->get_column($rs->result_class->path_column)) ) {
				return 0;
		}
		
	}

	return 1;
	
}

done_testing();