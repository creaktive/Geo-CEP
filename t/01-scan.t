#!perl -T
use strict;

use open ':locale';
use Test::More;

BEGIN {
    use_ok('Benchmark', qw(timediff timestr timesum));
    use_ok('Geo::CEP');
}

my $gc = new Geo::CEP;
isa_ok($gc, 'Geo::CEP');
can_ok($gc, qw(find list));

my $benchmark = timediff(new Benchmark, new Benchmark);
isa_ok($benchmark, 'Benchmark');

my $list = $gc->list;
my $i = 0;
while (my ($name, $row) = each %{$list}) {
    my $test = $row->{cep_initial} + int(rand($row->{cep_final} - $row->{cep_initial}));

    my $t0      = new Benchmark;
    my $r       = $gc->find($test);
    my $t1      = new Benchmark;
    $benchmark  = timesum($benchmark, timediff($t1, $t0));

    ok(ref($r) eq 'HASH', 'found');
    next unless $r;

    ok(
        $r->{$_} eq $row->{$_},
        sprintf('%s mismatch: "%s" != "%s"', $_, $r->{$_}, $row->{$_})
    ) for qw(state state_long ddd city lat lon);
} continue {
    ++$i;
}

diag('benchmark: ' . timestr($benchmark));
diag(sprintf('speed: %0.2f queries/second', $i / ($benchmark->[1] + $benchmark->[2])));

done_testing(5 + ($i * 7));
