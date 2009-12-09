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
});

ok ( check_rs( $rs, [0, 1] ), "Initial state" );

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
	
	my $expected_parent   = $expected_position_pairs->[0];
	my $expected_position = $expected_position_pairs->[1];
	my $actual_parent     = $chief->get_parent;
	my $actual_position   = $chief->get_column($chief->path_column);
	print "Expected Parent: $expected_parent\n";
	print "Expected Position: $expected_position\n";
	print "Actual Parent: $actual_parent\n";
	print "Actual Position: $actual_position\n";
	if ( 
		($expected_parent, $expected_position) != 
		($actual_parent,   $actual_position) ) {
			return 0;
	}
	return 1;
	
}

done_testing();