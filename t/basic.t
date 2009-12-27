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
  #children => [
   # {
      #name => 'subordinate 1',
     # children => [
    #    map { { name => 'rookie 1.' . $_ } } qw/1 2 3/,
   #   ],
  #  },
  #  {
  #    name => 'subordinate 2',
  #    children => [
  #      map { { name => 'rookie 2.' . $_ } } qw/1 2/,
  #    ],
  #  },
 # ]
});

ok ( check_rs( $rs, [ [ undef, 1 ] ] ), "Initial state" );
#ok ( check_rs( $rs, [ "1", "1.1"  ] ), "First subordinate" );
#ok ( check_rs( $rs, [ "1.1", "1.1.1"  ] ), "First child" );
#ok ( check_rs( $rs, [ "1.1", "1.1.2"  ] ), "Second child" );
#ok ( check_rs( $rs, [ "1.1", "1.1.3"  ] ), "Third child" );
#$rs->find ({name => 'rookie 1.2'})->update ({ parent_id => $chief->id });
#ok( check_rs ($rs, [1.1, 1.1.1]), 'promote a rookie to a subordinate' );

#$rs->find ({name => 'rookie 1.2'})->move_to(1);
#dump_rs ($rs, 'make this same rookie 1st subordinate');

#$rs->find ({name => 'rookie 1.2'})->move_to_group(undef, 1);
#dump_rs ($rs, 'damn he is good - promote him to FIRST chief (this time use move_to_group)');

#$rs->find ({name => 'rookie 1.2'})->move_to(2);
#dump_rs ($rs, 'not that good - make 2nd chief');

#my $sub2id = $rs->find ({name => 'subordinate 2'})->id;

#$rs->find ({name => 'rookie 1.2'})->move_to_group($sub2id);

sub check_rs {
	my ($rs, $expected_position_pairs) = @_;
#	10:10 <@ribasushi> dhoss: that'll do too, but I was suggesting more explicitness
#	10:10 < dhoss> how so?
#	10:10 <@ribasushi> i.e. check_rs ($rs, [  [1,1], [2, '1.1'], [3, '1.2' ] ] )...
#	10:12 <@ribasushi> what you really want is to set a relationship on the test 
#	                   schema
#	10:12 <@ribasushi> which will give you an independent way to get the parent
#	10:12 <@ribasushi> then you check if $row->path contains $row->parent->path
	
	my $actual_parent;
	my $actual_path;
	my ($x, $y) = 0;
	my $expected_parent;
	my $expected_position;
	while ( my $row = $rs->next ) {
		$expected_parent   = $expected_position_pairs->[$x];
		$expected_position =  $expected_position_pairs->[$x][$y];
		$expected_parent ||= "none";
		print "Expected Parent: $expected_parent\n";
		print "Expected Position: $expected_position\n";
		$actual_parent = $row->get_column($rs->result_class->path_column) ne "1" ? $row->parent->path : "none";
		$actual_path   = $row->get_column($rs->result_class->path_column);
		print "Actual Parent: "   . $actual_parent . "\n";
		print "Actual Position: " .  $row->get_column($rs->result_class->path_column) . "\n";
		if ( 
			( $expected_parent, $expected_position ) ne 
			( $actual_parent,   $actual_path       ) ) {
				return 0;
		}
		$x++, $y++;
		
	}
    
	return 1;
	
}

done_testing();