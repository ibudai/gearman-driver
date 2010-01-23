package    # hide from PAUSE
  Live::NS1::OverrideAttributes;

use base qw(Gearman::Driver::Worker);
use Moose;

sub override_attributes {
    return {
        MinProcesses => 1,
        Encode       => 'encode',
        Decode       => 'decode',
    };
}

sub job1 : Job : MinProcesses(5) : Encode(invalid) : Decode(invalid) {
    my ( $self, $job, $workload ) = @_;
    return $workload;
}

sub job2 : Job : MinProcesses(5) : Encode(invalid) : Decode(invalid) {
    my ( $self, $job, $workload ) = @_;
    return $workload;
}

sub job3 : Job : MinProcesses(5) : Encode(invalid) : Decode(invalid) {
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
