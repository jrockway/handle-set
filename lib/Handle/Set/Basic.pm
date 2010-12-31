package Handle::Set::Basic;
# ABSTRACT: a generic C<Handle::Set> over any type of perl filehandle
use Moose;
use true;
use namespace::autoclean;

with 'Handle::Set';

use AnyEvent;
use AnyEvent::Util;
use MooseX::Types::Set::Object;
use Set::Object qw(set);
use Set::Object::Weak qw(weak_set);
use Hash::Util::FieldHash qw(fieldhash);
use POSIX qw(EWOULDBLOCK EAGAIN);
use Scalar::Util qw(weaken);

has 'handles' => (
    isa     => 'Set::Object',
    default => sub { shift->is_weak ? weak_set : set },
    handles => {
        _add_handle    => 'insert',
        _delete_handle => 'remove',
        handles        => 'members',
    },
);

has 'watchers' => (
    isa    => 'HashRef[ArrayRef]', # [ $data, $watcher ]
    traits => ['Hash'],
    default => sub { fieldhash(my %hash) },
    handles => {
        _insert_watcher_for    => 'set',
        _watcher_state_for     => 'get',
        _has_write_watcher_for => 'exists',
        _delete_watcher_for    => 'delete',
    },
);

sub add_handle {
    my ($self, $h) = @_;
    fh_nonblocking $h, 1;
    $self->_add_handle($h);
}

sub delete_handle {
    my ($self, $h) = @_;
    $self->_delete_handle($h);
    $self->_delete_watcher_for($h);
}

sub _try_write {
    my ($self, $handle, $data) = @_;
    return unless defined $data && length($data) > 0;

    my $bytes = syswrite $handle, $data;

    if ($bytes < 0 && ($! != EWOULDBLOCK || $! != EAGAIN )){
        $self->_report_error("Write error: $!", $handle);
        return;
    }

    return substr $data, $bytes;
}

sub _defer_write {
    my ($self, $handle, $data) = @_;
    return unless defined $data && length($data) > 0;

    if($self->_has_write_watcher_for($handle)){
        my $state = $self->_watcher_state_for($handle);
        $state->[0] .= $data;
    }
    else {
        weaken $self;
        weaken $handle;
        my $state = [ $data ];

        $state->[1] = AnyEvent->io( fh => $handle, poll => 'w', cb => sub {
            if($self && $handle){ # may have gone out of scope
                $state->[0] = $self->_try_write($handle, $state->[0]);
                undef $state unless defined $state->[0] && length($state->[0]) > 0;
            }
            else {
                undef $state;
            }
        });

        $self->_insert_watcher_for( $handle, $state );
    }
}

sub push_write {
    my ($self, @data) = @_;
    my $data = join '', @data;

    my $size = length $data;
  handle:
    for my $handle ( $self->handles ) {
        my $more = $self->_try_write($handle, $data);
        $self->_defer_write($handle, $more) if length $more > 0;
    }

    return;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 SYNOPSIS

    my $set = Handle::Set::Basic->new;
    $set->add_handle($socket1);
    $set->add_handle($socket2);
    $set->add_handle($socket3);

    $set->push_write('Hi, everybody!');

=head1 DESCRIPTION

A generic C<Handle::Set> for anything L<AnyEvent> can apply an IO
watcher to.

=head1 SEE ALSO

L<Handle::Set>
