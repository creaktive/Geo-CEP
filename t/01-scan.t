#!perl
use strict;
use utf8;
use warnings qw(all);

use open qw(:std :utf8);
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

my $size = scalar keys %{$list};
is($size, 9608, 'database size');
diag("database has $size cities");

is($gc->find(0), 0, 'non-existent CEP');
is($gc->find(-1), 0, 'below valid CEP');
is($gc->find(999_999_999), 0, 'above valid CEP');

my $i = 0;
while (my ($name, $row) = each %{$list}) {
    my $test = $row->{cep_initial} + int(rand($row->{cep_final} - $row->{cep_initial}));

    my $t0      = Benchmark->new;
    my $r       = $gc->find($test);
    my $t1      = Benchmark->new;
    $benchmark  = timesum($benchmark, timediff($t1, $t0));

    is(ref($r), 'HASH', 'found');
    next unless $r;

    is(
        $r->{$_},
        $row->{$_},
        sprintf('%s mismatch: "%s" != "%s"', $_, $r->{$_}, $row->{$_})
    ) for qw(state state_long ddd city lat lon);
} continue {
    ++$i;
}

diag('benchmark: ' . timestr($benchmark));
diag(sprintf('speed: %0.2f queries/second', $i / ($benchmark->[1] + $benchmark->[2])));

done_testing(9 + ($i * 7));
