package Gearman::Driver::Observer;

use Moose;
use Net::Telnet::Gearman;
use POE;

=head1 NAME

Gearman::Driver::Observer - Observes gearmand status interface

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 callback

=cut

has 'callback' => (
    is       => 'rw',
    isa      => 'CodeRef',
    required => 1,
);

=head2 interval

=cut

has 'interval' => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
);

=head2 server

=cut

has 'server' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

=head2 gearman

=cut

has 'gearman' => (
    default => sub { [] },
    is      => 'ro',
    isa     => 'ArrayRef[Net::Telnet::Gearman]',
);

=head2 session

=cut

has 'session' => (
    is  => 'ro',
    isa => 'POE::Session',
);

=head1 METHODS

=cut

sub BUILD {
    my ($self) = @_;

    foreach my $server ( split /,/, $self->server ) {
        my ( $host, $port ) = split /:/, $server;

        push @{ $self->{gearman} },
          Net::Telnet::Gearman->new(
            Host => $host || 'localhost',
            Port => $port || 4730,
          );
    }

    $self->{session} = POE::Session->create(
        object_states => [
            $self => {
                _start       => '_start',
                fetch_status => '_fetch_status'
            }
        ]
    );
}

sub _start {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
    $kernel->yield('fetch_status');
}

sub _fetch_status {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
    my %data = ();
    foreach my $gearman ( @{ $self->{gearman} } ) {
        my $status = $gearman->status;
        foreach my $row (@$status) {
            $data{ $row->name } ||= {
                name    => $row->name,
                busy    => 0,
                free    => 0,
                queue   => 0,
                running => 0,
            };
            $data{ $row->name }{busy}    += $row->busy;
            $data{ $row->name }{free}    += $row->free;
            $data{ $row->name }{queue}   += $row->queue;
            $data{ $row->name }{running} += $row->running;
        }
    }
    $self->callback->( [ values %data ], $self->server );
    $kernel->delay( fetch_status => $self->interval );
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
