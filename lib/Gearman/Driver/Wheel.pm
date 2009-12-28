package Gearman::Driver::Wheel;

use Moose;
use Gearman::XS::Worker;
use Gearman::XS qw(:constants);
use POE qw(Wheel::Run);

=head1 NAME

Gearman::Driver::Wheel - TBD

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 driver

Reference to L<Gearman::Driver> instance.

=cut

has 'driver' => (
    handles  => { log => 'log' },
    is       => 'rw',
    isa      => 'Gearman::Driver',
    required => 1,
    weak_ref => 1,
);

=head2 method

=cut

has 'method' => (
    is       => 'rw',
    isa      => 'Class::MOP::Method',
    required => 1,
);

=head2 name

=cut

has 'name' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

=head2 worker

=cut

has 'worker' => (
    is       => 'rw',
    isa      => 'Any',
    required => 1,
);

=head2 server

=cut

has 'server' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

=head2 childs

=cut

has 'childs' => (
    is  => 'ro',
    isa => 'ArrayRef[POE::Wheel::Run]',
);

=head2 gearman

=cut

has 'gearman' => (
    is  => 'ro',
    isa => 'Gearman::XS::Worker',
);

=head2 session

=cut

has 'session' => (
    is  => 'ro',
    isa => 'POE::Session',
);

=head1 METHODS

=head2 add_child

=cut

sub add_child {
    my ($self) = @_;
    POE::Kernel->post( $self->session => 'add_child' );
}

sub BUILD {
    my ($self) = @_;

    $self->{gearman} = Gearman::XS::Worker->new;
    $self->gearman->add_servers( $self->server );

    my $wrapper = sub {
        $self->method->body->( $self->worker, $self->driver, @_ );
    };

    my $ret = $self->gearman->add_function( $self->name, 0, $wrapper, '' );
    if ( $ret != GEARMAN_SUCCESS ) {
        die $self->gearman->error;
    }

    $self->{session} = POE::Session->create(
        object_states => [
            $self => {
                _start           => '_start',
                got_child_stdout => '_on_child_stdout',
                got_child_stderr => '_on_child_stderr',
                got_child_close  => '_on_child_close',
                got_child_signal => '_on_child_signal',
                got_sig_int      => '_on_sig_int',
                add_child        => '_add_child',
            }
        ]
    );
}

sub _add_child {
    my ( $self, $kernel, $heap ) = @_[ OBJECT, KERNEL, HEAP ];

    my $child = POE::Wheel::Run->new(
        Program => sub {
            while (1) {
                my $ret = $self->gearman->work;
                if ( $ret != GEARMAN_SUCCESS ) {
                    die $self->gearman->error;
                }
            }
        },
        StdoutEvent => "got_child_stdout",
        StderrEvent => "got_child_stderr",
        CloseEvent  => "got_child_close",
        CloseOnCall => 1,
    );
    $kernel->sig_child( $child->PID, "got_child_signal" );

    # Wheel events include the wheel's ID.
    $heap->{children_by_wid}{ $child->ID } = $child;

    # Signal events include the process ID.
    $heap->{children_by_pid}{ $child->PID } = $child;

    $self->log->info( sprintf '(%d) [%s] Child started', $child->PID, $self->name );

    push @{ $self->{childs} }, $child;
}

sub _start {
    $_[KERNEL]->sig( INT => 'got_sig_int' );
}

sub _on_child_stdout {
    my ( $self, $heap, $stdout, $wid ) = @_[ OBJECT, HEAP, ARG0, ARG1 ];
    my $child = $heap->{children_by_wid}{$wid};
    $self->log->info( sprintf '(%d) [%s] STDOUT: %s', $child->PID, $self->name, $stdout );
}

sub _on_child_stderr {
    my ( $self, $heap, $stderr, $wid ) = @_[ OBJECT, HEAP, ARG0, ARG1 ];
    my $child = $heap->{children_by_wid}{$wid};
    $self->log->info( sprintf '(%d) [%s] STDERR: %s', $child->PID, $self->name, $stderr );
}

sub _on_child_close {
    my ( $self, $heap, $wid ) = @_[ OBJECT, HEAP, ARG0 ];

    my $child = delete $heap->{children_by_wid}{$wid};

    # May have been reaped by on_child_signal().
    unless ( defined $child ) {
        $self->log->info( sprintf '[%s] Closed all pipes', $self->name );
        return;
    }

    $self->log->info( sprintf '(%d) [%s] Closed all pipes', $child->PID, $self->name );

    delete $heap->{children_by_pid}{ $child->PID };
}

sub _on_child_signal {
    my ( $self, $heap, $pid, $status ) = @_[ OBJECT, HEAP, ARG1 .. ARG2 ];

    my $child = delete $heap->{children_by_pid}{$pid};

    $self->log->info( sprintf '(%d) [%s] Exited with status %s', $pid, $self->name, $status );

    # May have been reaped by on_child_close().
    return unless defined $child;

    delete $heap->{children_by_wid}{ $child->ID };
}

sub _on_sig_int {
    my ( $self, $kernel, $heap ) = @_[ OBJECT, KERNEL, HEAP ];

    foreach my $pid ( keys %{ $heap->{children_by_pid} } ) {
        my $child = delete $heap->{children_by_pid}{$pid};
        $child->kill();
        $self->log->info( sprintf '(%d) [%s] Child killed', $pid, $self->name );
    }

    $kernel->sig_handled();

    exit(0);
}

=head1 AUTHOR

Johannes Plunien E<lt>plu@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Johannes Plunien

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item * L<Gearman::Driver>

=back

=cut

1;
