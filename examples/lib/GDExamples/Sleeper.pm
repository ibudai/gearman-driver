package    # hide from PAUSE
  GDExamples::Sleeper;

use base qw(Gearman::Driver::Worker);
use Moose;

sub ZzZzZzzz : Job : MinProcs(5) : MaxProcs(10) {
    my ( $self, $job ) = @_;
    my $time = 5;
    sleep($time);
    $self->output( $job->workload );
}

sub output {
    my ( $self, $workload ) = @_;
    warn $workload;
}

1;
