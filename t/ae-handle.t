use strict;
use warnings;
use Test::More;
use Test::Exception;
use AnyEvent::Handle;
use AnyEvent::Util qw(portable_pipe fh_nonblocking);

use ok 'Handle::Set::AnyEvent::Handle';

my $set = Handle::Set::AnyEvent::Handle->new( is_weak => 1 );

my ($r1, $w1, $r2, $w2) = map {
    fh_nonblocking $_, 1;
    AnyEvent::Handle->new( fh => $_ );
} (portable_pipe, portable_pipe);

lives_ok {
    $set->add_handle($w1);
    $set->add_handle($w2);
} 'adding works';

lives_ok {
    $set->push_write("OH HAI\n");
} 'writing works';

my $done = AE::cv;
$r1->push_read( line => sub { $done->send($_[1]) } );
is $done->recv, 'OH HAI', 'got data on r1';
$done = AE::cv;
$r2->push_read( line => sub { $done->send($_[1]) } );
is $done->recv, 'OH HAI', 'got data on r2';

undef $r1;
undef $w1;

lives_ok {
    $set->push_write("OH HAI\n");
} 'writing still works';


$done = AE::cv;
$r2->push_read( line => sub { $done->send($_[1]) } );
is $done->recv, 'OH HAI', 'as does reading';

done_testing;
