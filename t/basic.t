use strict;
use warnings;
use Test::More;
use Test::Exception;
use AnyEvent::Util qw(portable_pipe fh_nonblocking);
use AnyEvent::Handle;

use ok 'Handle::Set::Basic';

my $set = Handle::Set::Basic->new;

lives_ok { $set->push_write('foo') } 'nothing to do, but that is ok';

my ($r1, $w1) = portable_pipe;
my ($r2, $d2) = portable_pipe; # sorry, had to

lives_ok {
    $set->add_handle($w1);
    $set->push_write("hello w1\n");
} 'add + write works';

{
    my $read = <$r1>;
    chomp $read;
    is $read, 'hello w1';

    lives_ok {
        $set->add_handle($d2);
        $set->push_write("i'm doctor nic!\n");
    } 'add + write works again';

    $read = <$r1>;
    chomp $read;
    is $read, q{i'm doctor nic!};

    $read = <$r2>;
    chomp $read;
    is $read, q{i'm doctor nic!};
}

fh_nonblocking $r1, 1;
fh_nonblocking $r2, 1;

my $rh1 = AnyEvent::Handle->new( fh => $r1 );
my $rh2 = AnyEvent::Handle->new( fh => $r2 );

my $done = AE::cv;
$done->begin for 1..2;

my ($data1, $data2);
$rh1->push_read( line => sub { $data1 = $_[1]; $done->end } );
$rh2->push_read( line => sub { $data2 = $_[1]; $done->end } );

my $big = 'x' x 65536 . "\n";
$set->push_write($big);

$done->recv;

chomp $big;
is $data1, $big, 'got correct data on handle 1';
is $data2, $big, 'got correct data on handle 2';

done_testing;
