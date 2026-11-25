# Copyright 2026 Google LLC
#
# Licensed under the the same terms as Perl itself (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use File::Temp qw(tempfile);
use PDL;
use PDL::IO::Arrow qw(
    rarrow warrow rparquet wparquet
    arrow2pdl_type pdl2arrow_type
);

# 1. Build a columnar table from 1-D PDL ndarrays
my $table = {
    event_id => long([101, 102, 103, 104]),
    latency  => double([12.4, 8.1, 25.6, 15.0]),
    score    => float([0.92, 0.85, 0.40, 0.97]),
};

# 2. Parquet round-trip
my ($pfh, $parquet_path) = tempfile('pdl_arrow_pq_XXXXXX', SUFFIX => '.parquet', UNLINK => 1);
close $pfh;

wparquet($table, $parquet_path);
my $pq_cols = rparquet($parquet_path);
printf "Parquet mean latency: %.2f ms\n", $pq_cols->{latency}->avg;

# 3. Arrow IPC round-trip
my ($afh, $arrow_path) = tempfile('pdl_arrow_ipc_XXXXXX', SUFFIX => '.arrow', UNLINK => 1);
close $afh;

warrow($table, $arrow_path);
my $ipc_cols = rarrow($arrow_path);

# 4. Inspect type mappings and filter rows with PDL
for my $col (sort keys %{$ipc_cols}) {
    my $pdl_t   = $ipc_cols->{$col}->type->ioname;
    my $arrow_t = pdl2arrow_type($pdl_t);
    my $back_t  = arrow2pdl_type($arrow_t);
    printf "Column %-10s PDL=%-8s Arrow=%-8s (roundtrip=%s)\n",
        $col, $pdl_t, $arrow_t, $back_t;
}

my $high_score = which($ipc_cols->{score} > 0.90);
print 'High-score event IDs: ', $ipc_cols->{event_id}->index($high_score), "\n";
