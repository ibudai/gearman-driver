package    # hide from PAUSE
  GDExamples::Sleeper;

use base qw(Gearman::Driver::Worker);
use Moose;

sub ZzZzZzzz : Job : MinChilds(3) : MaxChilds(6) {
    my ( $self, $driver, $job ) = @_;
    my $time = 2;
    sleep($time);
    $self->output( $job->workload );
}

sub output {
    my ( $self, $workload ) = @_;
    print "$workload\n";
}

sub long_running_ZzZzZzzz : Job : MinChilds(1) : MaxChilds(2) {
    my ( $self, $driver, $job ) = @_;
    my $time = 4;
    sleep($time);
    $self->output( $job->workload );
}

1;
