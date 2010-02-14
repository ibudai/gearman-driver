#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use TestLib;
use Live::NS3::AddJob;
use Live::NS3::AddJobChilds;
use Gearman::Driver::Job::Method;

my $driver = TestLib->gearman_driver;

my $w1 = Live::NS3::AddJob->new();
my $w2 = Live::NS3::AddJobChilds->new();

$driver->add_job(
    {
        max_processes => 5,
        min_processes => 1,
        name          => 'job_group_1',
        worker        => $w1,
        methods       => [
            {
                body   => $w1->meta->find_method_by_name('job1')->body,
                decode => 'custom_decode',
                encode => 'custom_encode',
                name   => 'job1',
            },
            {
                body => $w1->meta->find_method_by_name('begin_end')->body,
                name => 'begin_end',
            }
        ]
    }
);

$driver->add_job(
    {
        max_processes => 10,
        min_processes => 10,
        name          => 'ten_processes',
        worker        => $w1,
        methods       => [
            {
                body => $w1->meta->find_method_by_name('ten_processes')->body,
                name => 'ten_processes',
            }
        ]
    }
);

$driver->add_job(
    {
        max_processes => 6,
        min_processes => 2,
        name          => 'sleeper',
        worker        => $w1,
        methods       => [
            {
                body => $w1->meta->find_method_by_name('sleeper')->body,
                name => 'sleeper',
            }
        ]
    }
);

$driver->add_job(
    {
        max_childs => 5,
        min_childs => 1,
        name       => 'job_group_2',
        worker     => $w2,
        methods    => [
            {
                body   => $w2->meta->find_method_by_name('job1')->body,
                decode => 'custom_decode',
                encode => 'custom_encode',
                name   => 'job1',
            },
            {
                body => $w2->meta->find_method_by_name('begin_end')->body,
                name => 'begin_end',
            }
        ]
    }
);

$driver->add_job(
    {
        max_childs => 10,
        min_childs => 10,
        name       => 'ten_processes',
        worker     => $w2,
        methods    => [
            {
                body => $w2->meta->find_method_by_name('ten_processes')->body,
                name => 'ten_processes',
            }
        ]
    }
);

$driver->add_job(
    {
        max_childs => 6,
        min_childs => 2,
        name       => 'sleeper',
        worker     => $w2,
        methods    => [
            {
                body => $w2->meta->find_method_by_name('sleeper')->body,
                name => 'sleeper',
            }
        ]
    }
);

$driver->run;
