package    # hide from PAUSE
  TestLib;

use strict;
use warnings;
use FindBin qw( $Bin );
use Gearman::XS qw(:constants);
use Gearman::XS::Client;
use Gearman::XS::Server;
use Gearman::Driver;

my ( $host, $port ) = ( '127.0.0.1', 4731 );

$|++;

sub new { return bless {}, shift }

sub run_gearmand {
    my ($self) = @_;

    unless ( $self->{gearmand_pid} = fork ) {
        die "cannot fork: $!" unless defined $self->{gearmand_pid};

        my @cmd = ( $^X, "$Bin/gearmand.pl" );

        exec @cmd or die "Could not exec $Bin/gearmand.pl";

        exit(0);
    }
}

sub run_gearman_driver {
    my ($self) = @_;

    unless ( $self->{gearman_driver_pid} = fork ) {
        die "cannot fork: $!" unless defined $self->{gearman_driver_pid};

        my @cmd = ( $^X, "$Bin/gearman_driver.pl" );

        exec @cmd or die "Could not exec $Bin/gearman_driver.pl";

        exit(0);
    }
}

sub gearman_client {
    my $client = Gearman::XS::Client->new();
    $client->add_server( $host, $port );
    return $client;
}

sub gearman_server {
    return Gearman::XS::Server->new( $host, $port );
}

sub gearman_driver {
    return Gearman::Driver->new(
        interval   => 1,
        namespaces => [qw(Live)],
        server     => join( ':', $host, $port ),
    );
}

sub DESTROY {
    my ($self) = @_;

    foreach my $proc (qw/gearmand_pid gearman_driver_pid/) {
        system 'kill', $self->{$proc} if $self->{$proc};
    }
}

1;
