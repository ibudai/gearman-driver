use strict;
use warnings;
use Test::More tests => 28;
use FindBin;
use lib "$FindBin::Bin/lib";
use TestLib;
use File::Slurp;
use File::Temp qw(tempfile);

my $test = TestLib->new();
my $gc   = $test->gearman_client;

$test->run_gearmand;
$test->run_gearman_driver;

# give gearmand + driver at least 5 seconds to settle
for ( 1 .. 5 ) {
    my ( $ret, $pong ) = $gc->do( 'Live::NS1::Basic::ping' => 'ping' );
    sleep(1) && next unless $pong;
    is( $pong, 'pong', 'Job "Live::NS1::Basic::ping" returned correct value' );
    last;
}

{
    my ( $ret, $pong ) = $gc->do( 'something_custom_ping' => 'ping' );
    is( $pong, 'p0nG', 'Job "something_custom_ping" returned correct value' );
}

{
    my ( $ret, $pong ) = $gc->do( 'Live::NS2::Ping2::ping' => 'ping' );
    is( $pong, 'PONG', 'Job "Live::NS2::Ping2::ping" returned correct value' );
}

# i hope this assumption is always true:
# out of 1000 jobs all 10 childs handled at least one job
{
    my %pids = ();
    for ( 1 .. 1000 ) {
        my ( $ret, $pid ) = $gc->do( 'Live::NS1::Basic::ten_childs' => '' );
        $pids{$pid}++;
    }
    is( scalar( keys(%pids) ), 10, "10 different childs handled job 'ten_childs'" );
}

{
    my ( $ret, $pid ) = $gc->do( 'Live::NS1::Basic::get_pid' => '' );
    like( $pid, qr~^\d+$~, 'Job "get_pid" returned correct value' );
}

{
    $gc->do_background( 'Live::NS1::Basic::sleeper' => '5:' . time ) for 1 .. 5;    # blocks 5/6 slots for 5 secs

    my ( $ret, $time ) = $gc->do( 'Live::NS1::Basic::sleeper' => '0:' . time );
    ok( $time <= 2, 'Job "sleeper" returned in less than 2 seconds' );
}

{
    $gc->do_background( 'Live::NS1::Basic::sleeper' => '4:' . time );               # block last slot for another 4 secs

    my ( $ret, $time ) = $gc->do( 'Live::NS1::Basic::sleeper' => '0:' . time );
    ok( $time >= 2, 'Job "sleeper" returned in more than 2 seconds' );
}

{
    my ( $ret, $filename ) = $gc->do( 'Live::NS1::BeginEnd::job' => 'some workload ...' );
    my $text = read_file($filename);
    is(
        $text,
        "begin some workload ...\njob some workload ...\nend some workload ...\n",
        'Begin/end blocks in worker have been run'
    );
    unlink $filename;
}

{
    my ( $ret, $string ) = $gc->do( 'Live::NS1::Spread::main' => 'some workload ...' );
    is( $string, '12345', 'Spreading works (tests $worker->server attribute)' );
}

{
    my ( $ret, $string ) = $gc->do( 'Live::NS1::Encode::job1' => 'some workload ...' );
    is( $string, 'STANDARDENCODE::some workload ...::STANDARDENCODE', 'Standard encoding works' );
}

{
    my ( $ret, $string ) = $gc->do( 'Live::NS1::Encode::job2' => 'some workload ...' );
    is( $string, 'CUSTOMENCODE::some workload ...::CUSTOMENCODE', 'Custom encoding works' );
}

{
    my ( $ret, $string ) = $gc->do( 'Live::NS1::Decode::job1' => 'some workload ...' );
    is( $string, 'STANDARDDECODE::some workload ...::STANDARDDECODE', 'Standard decoding works' );
}

{
    my ( $fh, $filename ) = tempfile( CLEANUP => 1 );
    my ( $ret, $nothing ) = $gc->do_background( 'Live::NS2::BeginEnd::job' => $filename );
    sleep(2);
    my $text = read_file($filename);
    is( $text, "begin ...\nend ...\n", 'Begin/end blocks in worker have been run, even if the job dies' );
}

{
    my ( $ret, $string ) = $gc->do( 'Live::NS1::Decode::job2' => 'some workload ...' );
    is( $string, 'CUSTOMDECODE::some workload ...::CUSTOMDECODE', 'Custom decoding works' );
}

{
    my ( $fh, $filename ) = tempfile( CLEANUP => 1 );
    my ( $ret, $nothing ) = $gc->do( 'Live::NS2::UseBase::job' => $filename );
    my $text = read_file($filename);
    is( $text, "begin ...\njob ...\nend ...\n", 'Begin/end blocks in worker base class have been run' );
}

{
    my @nothing = $gc->do_background( 'Live::NS1::Basic::quit' => 'exit' );
    sleep(3);    # wait for the worker being restarted
    my ( $ret, $string ) = $gc->do( 'Live::NS1::Basic::quit' => 'foo' );
    is( $string, 'i am back', 'Worker child restarted after exit' );
}

{
    for ( 1 .. 3 ) {
        my ( $ret, $string ) = $gc->do( "Live::NS1::DefaultAttributes::job$_" => 'workload' );
        is(
            $string,
            'DefaultAttributes::ENCODE::DefaultAttributes::DECODE::'
              . 'workload::DECODE::DefaultAttributes::ENCODE::DefaultAttributes',
            'Encode/decode default attributes'
        );
    }
}

{
    for ( 1 .. 3 ) {
        my ( $ret, $string ) = $gc->do( "Live::NS1::OverrideAttributes::job$_" => 'workload' );
        is(
            $string,
            'OverrideAttributes::ENCODE::OverrideAttributes::DECODE::'
              . 'workload::DECODE::OverrideAttributes::ENCODE::OverrideAttributes',
            'Encode/decode override attributes'
        );
    }
}

{
    my ( $ret, $string ) = $gc->do( 'Live::job' => 'some workload ...' );
    is( $string, 'ok', 'loaded root namespace' );
}

{
    my ( $ret, $string ) = $gc->do( 'Live::NS3::AddJob::job1' => 'foo' );
    is( $string, 'CUSTOMENCODE::foo::CUSTOMENCODE', 'Custom encoding works' );
}

{
    my ( $ret, $filename ) = $gc->do( 'Live::NS3::AddJob::job2' => 'some workload ...' );
    my $text = read_file($filename);
    is(
        $text,
        "begin some workload ...\njob some workload ...\nend some workload ...\n",
        'Begin/end blocks in worker have been run'
    );
    unlink $filename;
}

# i hope this assumption is always true:
# out of 1000 jobs all 10 childs handled at least one job
{
    my %pids = ();
    for ( 1 .. 1000 ) {
        my ( $ret, $pid ) = $gc->do( 'Live::NS3::AddJob::ten_childs' => '' );
        $pids{$pid}++;
    }
    is( scalar( keys(%pids) ), 10, "10 different childs handled job 'Live::NS3::AddJob::ten_childs'" );
}

{
    $gc->do_background( 'Live::NS3::AddJob::sleeper' => '5:' . time ) for 1 .. 5;    # blocks 5/6 slots for 5 secs

    my ( $ret, $time ) = $gc->do( 'Live::NS3::AddJob::sleeper' => '0:' . time );
    ok( $time <= 2, 'Job "Live::NS3::AddJob::sleeper" returned in less than 2 seconds' );
}

{
    $gc->do_background( 'Live::NS3::AddJob::sleeper' => '4:' . time );               # block last slot for another 4 secs

    my ( $ret, $time ) = $gc->do( 'Live::NS3::AddJob::sleeper' => '0:' . time );
    ok( $time >= 2, 'Job "Live::NS3::AddJob::sleeper" returned in more than 2 seconds' );
}
