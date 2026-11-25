package PDL::IO::Arrow;

use 5.010;
use strict;
use warnings;
use Carp qw(croak);
use Exporter 'import';
use PDL::Core;
use PDL::Types;
use PDL::Slices;
use XSLoader;

our $VERSION = '0.011';

XSLoader::load('PDL::IO::Arrow', $VERSION);

use constant {
    FORMAT_ARROW   => 0,
    FORMAT_PARQUET => 1,
};

our @EXPORT = qw(
    rarrow
    warrow
    rparquet
    wparquet
);

our @EXPORT_OK = qw(
    rarrow
    warrow
    rparquet
    wparquet
    arrow2pdl_type
    pdl2arrow_type
);

my %ARROW_TO_PDL_TYPE = (
    float64 => 'double',
    double  => 'double',
    float32 => 'float',
    float   => 'float',
    int8    => 'sbyte',
    uint8   => 'byte',
    int16   => 'short',
    uint16  => 'ushort',
    int32   => 'long',
    uint32  => 'ulong',
    int64      => 'longlong',
    uint64     => 'ulonglong',
    bool       => 'byte',
    complex64  => 'cfloat',
    complex128 => 'cdouble',
);

my %PDL_TO_ARROW_TYPE = (
    double    => 'float64',
    float     => 'float32',
    sbyte     => 'int8',
    byte      => 'uint8',
    short     => 'int16',
    ushort    => 'uint16',
    long      => 'int32',
    ulong     => 'uint32',
    longlong  => 'int64',
    ulonglong => 'uint64',
    cfloat    => 'complex64',
    cdouble   => 'complex128',
);

my %PDL_ENUM = map { $_ => PDL::Type->new($_)->enum } keys %PDL_TO_ARROW_TYPE;

sub arrow2pdl_type {
    my ($arrow_type) = @_;
    return unless defined $arrow_type;
    return $ARROW_TO_PDL_TYPE{ lc($arrow_type) };
}

sub pdl2arrow_type {
    my ($pdl_type) = @_;
    return unless defined $pdl_type;
    my $name = ref($pdl_type) && $pdl_type->can('ioname') ? $pdl_type->ioname : $pdl_type;
    return $PDL_TO_ARROW_TYPE{ lc($name) };
}

sub _read_format {
    my ($source, $format, %opts) = @_;
    croak 'Source file path is required' unless defined $source;
    return _xs_read_pdls($source, $format, \%PDL_ENUM);
}

sub _write_format {
    my ($columns, $dest, $format, %opts) = @_;
    croak 'Columns hashref is required' unless ref($columns) eq 'HASH';
    croak 'Destination path is required' unless defined $dest;

    my @names = sort keys %$columns;
    my @pdls  = map { $columns->{$_}->flat } @names;
    _xs_write_pdls($dest, $format, \@names, \@pdls);
    return 1;
}

sub rarrow {
    my ($source, %opts) = @_;
    return _read_format($source, FORMAT_ARROW, %opts);
}

sub warrow {
    my ($columns, $dest, %opts) = @_;
    return _write_format($columns, $dest, FORMAT_ARROW, %opts);
}

sub rparquet {
    my ($source, %opts) = @_;
    return _read_format($source, FORMAT_PARQUET, %opts);
}

sub wparquet {
    my ($columns, $dest, %opts) = @_;
    return _write_format($columns, $dest, FORMAT_PARQUET, %opts);
}

1;

__END__

=encoding UTF-8

=head1 NAME

PDL::IO::Arrow - Read and write PDL ndarrays via Apache Arrow and Parquet

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    use PDL;
    use PDL::IO::Arrow qw(rarrow warrow rparquet wparquet);

    # Read Arrow IPC or Parquet columnar data into PDL ndarrays
    my $cols = rparquet('events.parquet');
    my $scores = $cols->{score};

    # Write named PDL columns to Parquet or Arrow IPC
    wparquet({ id => long([1, 2, 3]), val => double([0.5, 1.5, 2.5]) }, 'out.parquet');
    warrow({ id => long([1, 2, 3]), val => double([0.5, 1.5, 2.5]) }, 'out.arrow');

=head1 DESCRIPTION

C<PDL::IO::Arrow> provides a unified L<PDL::IO> interface to Apache Arrow IPC
and Apache Parquet columnar datasets backed by Apache Arrow C++
(C<libarrow> and C<libparquet>). It is designed for columnar data interchange
between L<PDL> (and L<Data::Frame>) and external analytics engines such as
Apache Spark (Spark Connect), BigQuery Storage Read API, DuckDB, and RAPIDS
cuDF.

=head1 FUNCTIONS

=head2 rarrow

=for ref

Read an Apache Arrow IPC file into a hashref of named PDL ndarrays.

=for usage

  $cols = rarrow($filename);

=for example

  my $cols = rarrow('events.arrow');
  my $scores = $cols->{score};

Reads all numeric (including complex) columns from the Apache Arrow IPC file
at C<$filename> and returns a hashref mapping column names to 1-D L<PDL>
ndarrays.

=head2 warrow

=for ref

Write a hashref of named PDL ndarrays to an Apache Arrow IPC file.

=for usage

  warrow(\%columns, $filename);

=for example

  warrow({ id => long([1, 2, 3]), val => double([0.5, 1.5, 2.5]) }, 'out.arrow');

Writes the named L<PDL> ndarrays in C<\%columns> to an Apache Arrow IPC file
at C<$filename>.

=head2 rparquet

=for ref

Read an Apache Parquet file into a hashref of named PDL ndarrays.

=for usage

  $cols = rparquet($filename);

=for example

  my $cols = rparquet('events.parquet');
  my $scores = $cols->{score};

Reads all numeric (including complex) columns from the Apache Parquet file at
C<$filename> via C<libparquet> and returns a hashref mapping column names to
1-D L<PDL> ndarrays.

=head2 wparquet

=for ref

Write a hashref of named PDL ndarrays to an Apache Parquet file.

=for usage

  wparquet(\%columns, $filename);

=for example

  wparquet({ id => long([1, 2, 3]), val => double([0.5, 1.5, 2.5]) }, 'out.parquet');

Writes the named L<PDL> ndarrays in C<\%columns> to an Apache Parquet file at
C<$filename> via C<libparquet>.

=head2 arrow2pdl_type

=for ref

Map an Apache Arrow type name to the corresponding PDL type name.

=for usage

  $pdl_type = arrow2pdl_type($arrow_type);

Maps an Apache Arrow primitive or complex type name (e.g. C<float64>,
C<float32>, C<int32>, C<int64>, C<uint8>, C<bool>, C<complex64>,
C<complex128>) to the corresponding L<PDL::Type> name.

=head2 pdl2arrow_type

=for ref

Map a PDL type name or L<PDL::Type> object to an Apache Arrow type name.

=for usage

  $arrow_type = pdl2arrow_type($pdl_type);

Maps a L<PDL::Type> object or type name to the corresponding Apache Arrow
type name.

=head1 TYPE MAPPING

=over 4

=item * C<float64> E<lt>=E<gt> C<double>

=item * C<float32> E<lt>=E<gt> C<float>

=item * C<int8> E<lt>=E<gt> C<sbyte>

=item * C<uint8> / C<bool> E<lt>=E<gt> C<byte>

=item * C<int16> E<lt>=E<gt> C<short>

=item * C<uint16> E<lt>=E<gt> C<ushort>

=item * C<int32> E<lt>=E<gt> C<long>

=item * C<uint32> E<lt>=E<gt> C<ulong>

=item * C<int64> E<lt>=E<gt> C<longlong>

=item * C<uint64> E<lt>=E<gt> C<ulonglong>

=back

=head1 SEE ALSO

L<PDL>, L<PDL::IO::Protobuf>, L<Data::Frame>, L<Protobuf>

=head1 TUTORIAL

This tutorial translates the Apache Arrow C++/Python columnar table and
Parquet/IPC round-trip quickstart into idiomatic Perl and L<PDL>.

=head2 1. Build a Columnar Table from PDL Ndarrays

In C<PDL::IO::Arrow>, a columnar table is represented as a Perl hashref mapping
column names to 1-D L<PDL> ndarrays of equal length:

    use strict;
    use warnings;
    use File::Temp qw(tempfile);
    use PDL;
    use PDL::IO::Arrow qw(
        rarrow warrow rparquet wparquet
        arrow2pdl_type pdl2arrow_type
    );

    my $table = {
        event_id => long([101, 102, 103, 104]),
        latency  => double([12.4, 8.1, 25.6, 15.0]),
        score    => float([0.92, 0.85, 0.40, 0.97]),
    };

=head2 2. Write and Read Apache Parquet

Write the columnar table to a Parquet file with L</wparquet> and read it back
with L</rparquet>:

    my ($pfh, $parquet_path) = tempfile(SUFFIX => '.parquet', UNLINK => 1);
    close $pfh;

    wparquet($table, $parquet_path);
    my $pq_cols = rparquet($parquet_path);

    printf "Parquet mean latency: %.2f ms\n", $pq_cols->{latency}->avg;

=head2 3. Write and Read Apache Arrow IPC

The same hashref can be serialized to Apache Arrow IPC (Feather v2) for
zero-copy interchange with Spark, DuckDB, or Polars:

    my ($afh, $arrow_path) = tempfile(SUFFIX => '.arrow', UNLINK => 1);
    close $afh;

    warrow($table, $arrow_path);
    my $ipc_cols = rarrow($arrow_path);

=head2 4. Inspect Type Mappings and Filter with PDL

Use L</pdl2arrow_type> and L</arrow2pdl_type> to inspect schema mappings, and
standard PDL indexing to filter rows:

    for my $col (sort keys %{$ipc_cols}) {
        my $pdl_t   = $ipc_cols->{$col}->type->ioname;
        my $arrow_t = pdl2arrow_type($pdl_t);
        printf "Column %-10s PDL=%-8s Arrow=%s\n", $col, $pdl_t, $arrow_t;
    }

    my $high_score = which($ipc_cols->{score} > 0.90);
    print 'High-score event IDs: ', $ipc_cols->{event_id}->index($high_score), "\n";

See C<examples/quickstart.pl> in the distribution for a complete runnable
script.

=head1 TYPES

Supports real numeric PDL types (C<byte>, C<sbyte>, C<short>, C<ushort>,
C<long>, C<ulong>, C<longlong>, C<ulonglong>, C<float>, C<double>) as well as
native complex types (C<cfloat> / C<complex64> and C<cdouble> / C<complex128>)
via Arrow fixed-size list / struct complex representations.

=head1 AUTHOR

C.J. Collier E<lt>cjac@google.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2026 Google LLC

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
