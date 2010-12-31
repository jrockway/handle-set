package Handle::Set::AnyEvent::Handle;
# ABSTRACT: C<Handle::Set> for sets of C<AnyEvent::Handle> objects
use Moose;
use true;
use namespace::autoclean;

use AnyEvent::Handle;

use MooseX::Types::Set::Object;
use Set::Object qw(set);
use Set::Object::Weak qw(weak_set);

has 'handles' => (
    isa     => 'Set::Object',
    default => sub { shift->is_weak ? weak_set : set },
    handles => {
        add_handle    => 'insert',
        delete_handle => 'remove',
        handles       => 'members',
    },
);

# TODO: make each handle's on_error our on_error?

sub push_write {
    my ($self, @data) = @_;
    my $data = join '', @data;

    $_->push_write($data) for $self->handles;
}

with 'Handle::Set';

__PACKAGE__->meta->make_immutable;

__END__

=head1 DESCRIPTION

L<Handle::Set> for handles that already do C<push_write>.

=head1 SEE ALSO

L<Handle::Set>
