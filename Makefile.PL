use 5.010;
use strict;
use warnings;
use Config;
use ExtUtils::MakeMaker;
use ExtUtils::CppGuess;
use PDL::Core::Dev;

if (system('pkg-config --exists arrow parquet 2>/dev/null') != 0) {
    die "libarrow-dev and libparquet-dev (pkg-config arrow parquet) are required to build PDL::IO::Arrow.\n";
}

my $cflags  = `pkg-config --cflags arrow parquet 2>/dev/null` || '';
my $libs    = `pkg-config --libs arrow parquet 2>/dev/null`   || '-lparquet -larrow';
my $pdl_inc = PDL::Core::Dev::PDL_INCLUDE();
chomp($cflags);
chomp($libs);

my $guess        = ExtUtils::CppGuess->new();
my %cpp_opts     = $guess->makemaker_options();
my $cpp_compiler = $guess->compiler_command() || 'g++';
my $cpp_libs     = $guess->linker_flags()     || '-lstdc++';
my $cpp_flags    = ($cpp_opts{CCFLAGS} || '') . ' -std=c++20';

my $extra_ldflags = $ENV{LDFLAGS} ? ' ' . $ENV{LDFLAGS} : '';

WriteMakefile(
    NAME               => 'PDL::IO::Arrow',
    AUTHOR             => q{C.J. Collier <cjac@google.com>},
    VERSION_FROM       => 'lib/PDL/IO/Arrow.pm',
    ABSTRACT_FROM      => 'lib/PDL/IO/Arrow.pm',
    LICENSE            => 'apache_2_0',
    MIN_PERL_VERSION   => '5.010',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
        'ExtUtils::CppGuess'  => '0.26',
        'PDL'                 => '2.080',
    },
    TEST_REQUIRES => {
        'Test::More' => '0.88',
    },
    PREREQ_PM => {
        'PDL'  => '2.080',
        'Carp' => '0',
    },
    INC       => '-I. ' . $pdl_inc . ' ' . $cflags,
    LIBS      => [ $libs . ' ' . $cpp_libs ],
    XS        => { 'Arrow.xs' => 'Arrow.c' },
    OBJECT    => 'Arrow$(OBJ_EXT) arrow_bridge$(OBJ_EXT)',
    LDDLFLAGS => $Config{lddlflags} . $extra_ldflags,
    LDFLAGS   => $Config{ldflags}   . $extra_ldflags,
    macro     => { CXX => $cpp_compiler, CXXFLAGS => $cpp_flags },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/PDLPorters/PDL-IO-Arrow.git',
                web  => 'https://github.com/PDLPorters/PDL-IO-Arrow',
            },
            bugtracker => {
                web => 'https://github.com/PDLPorters/PDL-IO-Arrow/issues',
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'PDL-IO-Arrow-* Arrow.c Arrow.bs *.o' },
);

package MY;

sub postamble {
    return <<"MAKE_FRAG";
arrow_bridge\$(OBJ_EXT): arrow_bridge.cc arrow_bridge.h
\t\$(CXX) \$(CXXFLAGS) -O2 -fPIC $cflags -I. -c arrow_bridge.cc -o arrow_bridge\$(OBJ_EXT)
MAKE_FRAG
}
