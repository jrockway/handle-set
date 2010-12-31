package Handle::Set;
# ABSTRACT: write to multiple IO handles with one method call
use Moose::Role;
use true;
use namespace::autoclean;

use Moose::Util::TypeConstraints qw(role_type);

role_type 'Handle::Set', { role => 'Handle::Set' };

has 'is_weak' => (
    is      => 'ro',
    isa     => 'Bool',
    default => sub { 0 },
);

has on_error => (
    is      => 'ro',
    isa     => 'CodeRef',
    default =>  sub {
        return sub {
            my ($self, $error, @handles) = @_;
            my $class = $self->meta->name;

            my $affecting = '';
            if(@handles) {
                my $count = scalar @handles;
                $affecting = ' affecting $count handle';
                $affecting .= 's' if @handles != 1;
                $affecting .= ' ';
            }

            warn "$class: error${affecting}in callback (ignoring): $error";
        };
    },
);

sub _report_error { # (error, @handles)
    my $self = shift;
    my $cb = $self->on_error;
    $self->$cb(@_);
}

requires 'add_handle';
requires 'delete_handle';
requires 'push_write';

__END__

=head1 SYNOPSIS

This is an API role.  Typical usage will look like:


   open my $fh1, ...;
   open my $fh2, ...;

   my $set = Some::Class->new( is_weak => 1, on_error => sub { die $_[1] } );

   $set->add_handle( $fh1 );
   $set->add_handle( $fh2 );
   $set->push_write( 'hello fh1 and fh2' );


=head1 DESCRIPTION

Sometimes you want to send the same data to multiple handles.  This
module provides an API for modules implementing this functionality.

=head1 API

=head2 new

Construct an empty handle set.

Accepts the following initargs:

=over 4

=item is_weak

True if you want a weak set instead of a regular set.  Defaults to
false.

=item on_error

Callback called when there is some sort of error.  Receives the set
object, the error message, and a list of 0 or more failing handles.
You may remove these handles from the set in the callback (but you
don't have to).

=back

=head2 add_handle($handle)

Register a handle.  Any messages written to the set will be written to
this handle until it is removed.

=head2 delete_handle($handle)

Deregister a handle.  No more messages written to the set will be
written to this handle.  Any messages that were queued but not sent
may still be sent, but this behavior is implementation-dependent.

=head2 push_write($data)

Write C<$data> to each handle in the set.  The data will be sent
immediately if possible, or queued on a per-handle basis if not
possible.

=head2 has_pending_writes

Returns true if there is some data that has not been written to all
sockets yet.

=head1 TYPE CONSTRAINTS

Loading this module registers the type constraint C<Handle::Set>,
which any class implementing this role will match.
