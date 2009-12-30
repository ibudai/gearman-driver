package    # hide from PAUSE
  Live::NS1::Spread;

use base qw(Gearman::Driver::Worker);
use Moose;
use Gearman::XS::Client;

has 'gc' => (
    default => sub { Gearman::XS::Client->new },
    is      => 'ro',
    isa     => 'Gearman::XS::Client',
);

sub BUILD {
    my ($self) = @_;
    $self->gc->add_servers( $self->server );
}

sub main : Job {
    my ( $self, $job ) = @_;
    my $result = '';
    for ( 1 .. 5 ) {
        my ( $ret, $res ) = $self->gc->do( "Live::NS1::Spread::some_job_$_" => '' );
        $result .= $res;
    }
    return $result;
}

sub some_job_1 : Job {
    return 1;
}

sub some_job_2 : Job {
    return 2;
}

sub some_job_3 : Job {
    return 3;
}

sub some_job_4 : Job {
    return 4;
}

sub some_job_5 : Job {
    return 5;
}

1;
