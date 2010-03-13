#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use Carp;
use Fatal qw(open close);
use English qw( -no_match_vars );

use Module::Build;

our $MINIMUM_MARPA_VERSION;
$MINIMUM_MARPA_VERSION = '0.012_000';
my $marpa_version_check =
    Module::Build->check_installed_status( 'Marpa', $MINIMUM_MARPA_VERSION );
if ( not $marpa_version_check->{ok} ) {
    Carp::croak( $marpa_version_check->{message} );
}
my $marpa_version = $marpa_version_check->{have};

my $marpa_html_version = '0.001_006';

Carp::croak("Failed to load Marpa: $EVAL_ERROR") if not eval { use Marpa; 1 };
if ( not Marpa->compatible( { 'Marpa::HTML' => $marpa_html_version } ) ) {
    Carp::croak(
        "Unsupported Marpa::HTML $marpa_html_version with Marpa $marpa_version"
    );
}

my $class = Module::Build->subclass(
    class => 'Module::Build::Custom',
    code  => <<'SUBCLASS' );

    sub ACTION_dist {
        my $self = shift;
        open( my $manifest_fh, q{<}, 'MANIFEST' )
            or die("Cannot open MANIFEST: $!");

        my @problems;
        FILE: while ( my $file = <$manifest_fh> ) {
            chomp $file;
            next FILE if $file =~ /^\s*[#]/xms;
            next FILE if $file !~ /[.](pl|pm|t)$/xmsi;
            my $file_text = do {
                local $/ = undef;
                if ( not -r $file ) {
                    Carp::carp("Cannot open $file: $!");
                    next FILE;
                }
                open( my $fh, q{<}, $file );
                <$fh>;
            };
            if ( $file_text =~ /^ \s+ use \s+ Smart[:][:]Comments /xms ) {
                push @problems, "Smart::Comments enabled in $file";
            }
        } ## end while ( my $file = <$manifest_fh> )

        Carp::carp(join "\n", @problems, "Fatal Error\n") if @problems;
        $self->SUPER::ACTION_dist;
    } ## end sub ACTION_dist
SUBCLASS

my $build = $class->new(
    dist_name     => 'Marpa-HTML',
    module_name   => 'Marpa::HTML',
    dist_author   => 'Jeffrey Kegler',
    dist_version  => $marpa_html_version,
    dist_abstract => 'High-level HTML Parsing',
    requires      => {
        'Scalar::Util'     => 0,
        'HTML::Parser'     => '3.64',
        'HTML::PullParser' => '3.57',
    },
    build_requires => { 'Test::More' => 0.94, },
    PL_files       => {},            # workaround Module::Build bug
    script_files => [ 'script/html_fmt', 'script/html_score', ],
    pod_files    => {
        'lib/Marpa/HTML/Doc/Support.pod' => 'lib/Marpa/Support.pod',
        'lib/Marpa/HTML/Doc/HTML.pod'    => 'lib/Marpa/HTML.pod',
    },
    meta_merge => {
        resources => {
            repository => 'git://github.com/jeffreykegler/Marpa--HTML.git',
        },
        no_index => {
            directory => [qw( inc t author.t save )],
            namespace => [
                'Marpa::HTML::Internal', 'Marpa::HTML::Display::Internal',
                'Marpa::HTML::Test',
            ],
            package => [

                # not public, at least for now
                qw(Marpa::HTML::Offset Marpa::HTML::Test Marpa::HTML::Display ),

                # never intended to see the light of day
                qw(Marpa::HTML::Internal),

            ],
        },
    },
    meta_add => {
        distribution_type => 'module',
        requires          => {
            'Marpa'            => $MINIMUM_MARPA_VERSION,
            'HTML::PullParser' => '3.57'
        },
        provides => {
            'Marpa::HTML' => {
                file    => 'lib/Marpa/HTML.pm',
                version => $marpa_html_version,
            },
        },
    },
    license            => 'perl',
    create_license     => 1,
    create_readme      => 0,
    create_makefile_pl => 'small',
    test_files => [ map { glob $_ } qw(t/*.t t/*/*.t lib/Marpa/HTML/t/*.t) ],
);

$build->create_build_script;
