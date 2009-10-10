package DBIx::Class::Tree::Recursive;


use Moose;
use MooseX::Types qw/ Str Int Bool /;
use namespace::autoclean;
extends 'DBIx::Class';

## stuff!

## I'm going to be dumb as hell for the time being, and assume the path
## is delimited with '.'.  This can change later.


=head2 $self->path
attrtibute for our current row's path.
=cut

has 'path' => (
    is  => 'ro',
    isa => Str,
    default => sub {
        my @path_array;
        
        ## later, I can change this to something like, 
        ## split ( $self->delimiter, @_ )
        push @path_array, $_ for split ('.', @_);
        @path_array;
    }
);

=head2 $self->parent
Get the parent of a given "node".
C<$self->has_parent> tells us if said child has a parent or not.
C<$self->parent> tells us that our node has no further parents. CS101.
=cut
has 'parent' => (
    is  => 'ro',
    isa => 'DBIx::Class::ResultSet',
    predicate => 'has_parent',
    weak_ref => 1,

);

=head2 $self->(current_node|node($id))->child
First direct child of of C<$self->current_node> or
C<$self->node($id)> where C<$id> is the primary key of the row in question.
Returns ONE child row. 
=cut

## this is probably horrifically evil
has 'child' => (
    is => 'ro',
    isa => 'DBIx::Class::ResultSet',
    predicate => 'has_child',
    default => sub {
        my ($self, $node) = @_;
        my $rs = $self->search( 
          { 
            path => $node->path .'%' 
          },
          {
            limit => 1
          }
        );
        
        return $rs->first;
    },
    
    trigger => \&_set_parent_for_child
    
);

sub _set_parent_for_child {
    my ( $self, $child ) = @_;

    confess "You cannot insert a tree which already has a parent"
        if $child->has_parent;

    $child->parent($self);
}

=head2 $self->get_all_children($node)
Get all descendents of a given node.
=cut
sub get_all_children {
    my $self = @_;
    my $rs = $self->search( 
      {
        path => $self->path . '%',    
      }
    );
    
    return $rs->all;
}

=head2 $self->get_all_ancestors($node)
Get all ancestors of a given node. Basically, just return the path 
above the current node in a "nice" format.
=cut
sub get_all_ancestors {
    my $self = @_;
    my $rs = $self->search(
      {
        path => '%' . %self->path   
      }
    );
    
    return $rs->all;
}


=head2 $self->add_child($node, $child_path, $content)
Add a child to a given node. 
=cut
sub add_child {
    my ($self, $child_path, $content) = @_;
    my $rs = $self->create(
	    $content, 
	    path => $self->path . $child_path
	);
	
	return $rs;
}

=head2 $self->set_parent($new_parent_path), $self->set_parent($node, $new_parent_path)
Reparent a given node.  If only one argument supplied, reparent the current node.
Otherwise, reparent the node that's the first argument with the second argument.
=cut
sub set_parent {
    my ($self, $new_parent_path, $content) = @_;
    my $rs = $self->create(
	    $content, 
	    $new_parent_path . $self->path
	);
	
	return $rs;
}
1;