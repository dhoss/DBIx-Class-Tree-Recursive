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
ok(
    check_rs(
        $rs,
        [
            [ "null", 1 ],
            [ 1,      "1.1" ],
            [ 2,      "1.1.1" ],
            [ 2,      "1.1.2" ],
            [ 2,      "1.1.3" ],
            [ 1,      "1.2" ],
            [ 6,      "1.2.1" ],
            [ 6,      "1.2.2" ],

        ],
        "initial state"
    )
);

$rs->find( { name => "rookie 1.2" } )
  ->update( { parent_id => $rs->find( { name => "grand chief" } )->id } );
ok(
    check_rs(
        $rs,
        [
            [ "null", 1 ],
            [ 1,      "1.1" ],
            [ 2,      "1.1.1" ],
            [ 1,      "1.1.2" ],
            [ 2,      "1.1.2" ],
            [ 1,      "1.2" ],
            [ 6,      "1.2.1" ],
            [ 6,      "1.2.2" ],

        ],
        "make rookie 1.2 a subordinate"
    )
);

$rs->find( { name => "rookie 1.2" } )->move_to(1);
ok(
    check_rs(
        $rs,
        [
            [ "null", 1 ],
            [ 1,      "1.2" ],
            [ 2,      "1.2.1" ],
            [ 1,      "1.1" ],
            [ 2,      "1.2.2" ],
            [ 1,      "1.2" ],
            [ 6,      "1.2.1" ],
            [ 6,      "1.2.2" ],

        ],
        "make this same rookie 1st subordinate"
    )
);

$rs->find( { name => 'rookie 1.2' } )->move_to_group( undef, 1 );
ok(
    check_rs(
        $rs,
        [
            [ "null", 1 ],
            [ 1,      "1.1" ],
            [ 2,      "1.1.1" ],
            [ "null", "1.1" ],
            [ 2,      "1.1.2" ],
            [ 1,      "1.1" ],
            [ 6,      "1.1.1" ],
            [ 6,      "1.1.2" ],
        ],
        "promote him to FIRST chief (this time use move_to_group)"
    )
);

$rs->find( { name => 'rookie 1.2' } )->move_to(2);
ok(
    check_rs(
        $rs,
        [
            [ "null", 1 ],
            [ 1,      "1.1" ],
            [ 2,      "1.1.1" ],
            [ "null", 2 ],
            [ 2,      "1.1.2" ],
            [ 1,      "1.1" ],
            [ 6,      "1.1.1" ],
            [ 6,      "1.1.2" ],

        ],
        "not that good - make 2nd chief"
    )
);

my $sub2id = $rs->find( { name => 'subordinate 2' } )->id;

$rs->find( { name => 'rookie 1.2' } )->move_to_group($sub2id);
ok(
    check_rs(
        $rs,
        [
            [ "null", 1 ],
            [ 1,      "1.1" ],
            [ 2,      "1.1.1" ],
            [ 6,      "1.1.3" ],
            [ 2,      "1.1.2" ],
            [ 1,      "1.1" ],
            [ 6,      "1.1.1" ],
            [ 6,      "1.1.2" ],

        ],
        "This guy is retarded, demote to last subordinate of 2nd subordinate"
    )
);

sub check_rs {
    my ( $rs, $expected_pairs, $description ) = @_;

#	10:10 <@ribasushi> dhoss: that'll do too, but I was suggesting more explicitness
#	10:10 < dhoss> how so?
#	10:10 <@ribasushi> i.e. check_rs ($rs, [  [1,1], [2, '1.1'], [3, '1.2' ] ] )...
#	10:12 <@ribasushi> what you really want is to set a relationship on the test
#	                   schema
#	10:12 <@ribasushi> which will give you an independent way to get the parent
#	10:12 <@ribasushi> then you check if $row->path contains $row->parent->path

    ## check to make sure the parent is correct, and the path is correct

    my @paths;
    for (
        $rs->search(
            {}, { columns => [qw/path parent_id/], order_by => 'id' }
        )->cursor->all
      )
    {
        my ( $pos_raw_value, $parent_raw_value ) = @$_;
        $parent_raw_value ||= "null";

        push @paths, [ $parent_raw_value, $pos_raw_value ];

    }
    warn "got:\n"
      . Dumper( \@paths )
      . "\nexpected:\n"
      . Dumper $expected_pairs;
    is_deeply( \@paths, $expected_pairs, $description );

}

done_testing();
