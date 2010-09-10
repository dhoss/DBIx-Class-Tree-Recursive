package Schema::Result::Test;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ Tree::Ordered::MatPath Core /);
__PACKAGE__->table('nested');
__PACKAGE__->add_columns(
    id        => { data_type => 'int', is_auto_increment => 1 },
    name      => { data_type => 'varchar' },
    parent_id => { data_type => 'int', is_nullable       => 1 },
    path      => { data_type => 'varchar', },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many( 'children', __PACKAGE__, 'parent_id' );
__PACKAGE__->belongs_to( 'parent', __PACKAGE__, 'parent_id' );
__PACKAGE__->add_unique_constraint( [qw/ path /] );
__PACKAGE__->position_column('path');
__PACKAGE__->grouping_column('parent_id');
1;
