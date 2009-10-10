use Test::More qw/ no_plan /;
use DBIx::Class::Tree::Recursive;
use DBIC::TestDatabase;
my $tree = DBIx::Class::Tree::Recursive->new(%options);

## create a new tree
create_test_db();

## insert some nodes
my $root  = $tree->create(%options);
my $child = $tree->add_child($root, %data);
my $child2 = $tree->add_child($child, %data);


## let's do some traversal
my $number_of_children = scalar $tree->get_all_children($root);

## test to make sure $root has 1 child, and $child has one child

## shit to create a test db
sub create_test_db {}

done_testing;