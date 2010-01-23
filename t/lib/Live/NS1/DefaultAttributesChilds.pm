package    # hide from PAUSE
  Live::NS1::DefaultAttributesChilds;

use base qw(Gearman::Driver::Worker);
use Moose;

sub default_attributes {
    return {
        MinChilds => 3,
        Encode    => 'encode',
        Decode    => 'decode',
    };
}

sub job1 : Job {
    my ( $self, $job, $workload ) = @_;
    return $workload;
}

sub job2 : Job {
    my ( $self, $job, $workload ) = @_;
    return $workload;
}

sub job3 : Job {
    my ( $self, $job, $workload ) = @_;
    return $workload;
}

sub encode {
    my ( $self, $result ) = @_;
    my $package = ref($self);
    return "${package}::ENCODE::${result}::ENCODE::${package}";
}

sub decode {
    my ( $self, $workload ) = @_;
    my $package = ref($self);
    return "${package}::DECODE::${workload}::DECODE::${package}";
}

1;
