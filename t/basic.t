use strict;
use warnings;
use Test::More;
use lib "t/lib";
use Schema;
use Data::Dumper;
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
ok( !defined $chief->parent, "chief has no parent" );

ok( check_rs( $rs->find( { name => "subordinate 1" } ), [ 1, "1.1" ] ),
    "first subordinate" );
cmp_ok( $rs->find( { name => "subordinate 1" } )->parent->id,
    '==', $chief->id, 'first subordinate has chief as parent' );

ok( check_rs( $rs->find( { name => "subordinate 2" } ), [ 1, "1.2" ] ),
    "second subordinate" );
cmp_ok( $rs->find( { name => "subordinate 2" } )->parent->id,
    '==', $chief->id, 'second subordinate has chief as parent' );

ok( check_rs( $rs->find( { name => "rookie 1.1" } ), [ "1.1", "1.1.1" ] ),
    "first child" );
cmp_ok(
    $rs->find( { name => "rookie 1.1" } )->parent->id,
    '==',
    $rs->find( { name => "subordinate 1" } )->id,
    "child 1 has subordinate 1 as a parent"
);

ok( check_rs( $rs->find( { name => "rookie 1.2" } ), [ "1.1", "1.1.2" ] ),
    "second child" );
cmp_ok(
    $rs->find( { name => "rookie 1.2" } )->parent->id,
    '==',
    $rs->find( { name => "subordinate 1" } )->id,
    "child 2 has subordinate 1 as a parent"
);

# move shit around
$rs->find( { name => "rookie 1.2" } )
  ->update( { parent_id => $rs->find( { name => "grand chief" } )->id } );
ok( check_rs( $rs->find( { name => "rookie 1.2" } ), [ 1, "1.1.2" ] ),
    'promote a rookie to a subordinate' );
cmp_ok(
    $rs->find( { name => "rookie 1.1" } )->parent->id,
    '==',
    $rs->find( { name => "subordinate 1" } )->id,
    "child 1 has subordinate 1 as a parent"
);

$rs->find( { name => "rookie 1.1" } )->move_to(1);
ok( check_rs( $rs->find( { name => "rookie 1.1" } ), [ '1.1', "1.1.1" ] ),
    'make this same rookie 1st subordinate' ); # this seems wrong
$rs->find( { name => "rookie 1.1" } )->move_to_group( undef, 1 ); 

ok(
    check_rs( $rs->find( { name => 'rookie 1.1' } ), [ undef, "1.1.1" ] ),
    "promote him to FIRST chief (this time use move_to_group)"
);

$rs->find( { name => "rookie 1.1" } )->move_to(2);    ## issues here

ok( check_rs( $rs->find( { name => "rookie 1.1" } ), [ undef, 2 ] ),
    'not that good - make 2nd chief' );
my $sub2id = $rs->find( { name => 'subordinate 2' } )->id;

$rs->find( { name => "rookie 1.2" } )->move_to_group($sub2id);
warn "moved to second sub: " . $rs->find( { name => "rookie 1.2" } )->path . ", parent: " . $rs->find( { name => "rookie 1.2" } )->parent->id;
ok( check_rs( $rs->find( { name => 'rookie 1.2' } ), [ "1.2", "1.2.3" ] ),
    "moved to second sub of first chief" );

## ought to modify check_rs to handle this
my @direct_children;
warn "direct chillun: " .  $_->path for $rs->find( { name => 'subordinate 1' } )->direct_children->all;
for my $child ( $rs->find( { name => 'subordinate 1' } )->direct_children->all ) {
    push @direct_children, $child->path;
}

my @should_have_children_paths =
  ( "1.1.1" );
is_deeply(
    \@direct_children,
    \@should_have_children_paths,
    "paths match for direct children"
);

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

    my $expected_first =
      !( $expected_pairs->[0] ) ? " null " : $expected_pairs->[0];
    my $path = ( $node->parent && $node->parent->path ) || " null ";  # if ->parent doesn't return undef, then $path = $node->parent->path
    warn "path : $path";
    unless ( ( $path eq $expected_first )
        && ( $node->path eq $expected_pairs->[1] ) )
    {
        return 0;
    }

    return 1;

}

done_testing();
