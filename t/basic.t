use strict;
use warnings;
use Test::More;
use lib "t/lib";
use Schema;
my $schema = Schema->connect('dbi:SQLite::memory:');

$schema->deploy;
my $rs = $schema->resultset('Test');

my $chief = $rs->create(
    {
        name     => 'grand chief',
        children => [
            {
                name     => 'subordinate 1',
                children => [ map { { name => 'rookie 1.' . $_ } } qw/1 2 3/, ],
            },
            {
                name     => 'subordinate 2',
                children => [ map { { name => 'rookie 2.' . $_ } } qw/1 2/, ],
            },
        ]
    }
);

ok( check_rs( $chief, [ undef, 1 ] ), "initial state" );

ok( check_rs( $rs->find( { name => "subordinate 1" } ), [ 1, "1.1" ] ), "first subordinate" );

ok( check_rs( $rs->find( { name => "subordinate 2" } ), [ 1, "1.2" ] ), "second subordinate" );

ok ( check_rs( $rs->find( { path => "1.1.1" } ), [ "1.1", "1.1.1"  ] ), "first child" );
#ok ( check_rs( $rs, [ "1.1", "1.1.2"  ] ), "second child" );
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
    my ( $node, $expected_pairs ) = @_;

    #	10:10 <@ribasushi> dhoss: that'll do too, but I was suggesting more explicitness
    #	10:10 < dhoss> how so?
    #	10:10 <@ribasushi> i.e. check_rs ($rs, [  [1,1], [2, '1.1'], [3, '1.2' ] ] )...
    #	10:12 <@ribasushi> what you really want is to set a relationship on the test
    #	                   schema
    #	10:12 <@ribasushi> which will give you an independent way to get the parent
    #	10:12 <@ribasushi> then you check if $row->path contains $row->parent->path

    ## check to make sure the parent is correct, and the path is correct
    $node->discard_changes;
    my $expected_first = ( $expected_pairs->[0] eq undef ) ? "null" : $expected_pairs->[0];
    warn "expected pair: 1: " . $expected_first . ", 2: " . $expected_pairs->[1];
    my $path = ( $node->parent && $node->parent->path ) || "null";
    unless ( ( $path eq $expected_first )
        && ( $node->path eq $expected_pairs->[1] ) )
    {
        warn "got to return 0";
        return 0;
    }

    warn "got to return 1";
    return 1;

}

done_testing();
