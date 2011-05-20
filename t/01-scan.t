#!perl -T
use strict;

use open ':locale';
use Test::More;

BEGIN {
    use_ok('Geo::CEP');
}

my $gc = new Geo::CEP;
isa_ok($gc, 'Geo::CEP');
can_ok($gc, qw(find list));

my $list = $gc->list;
my $i = 0;
while (my ($name, $row) = each %{$list}) {
    my $test = $row->{cep_initial} + int(rand($row->{cep_final} - $row->{cep_initial}));
    my $r = $gc->find($test);

    ok(ref($r) eq 'HASH', 'found');
    next unless $r;

    ok($r->{$_} eq $row->{$_}, sprintf('%s mismatch: "%s" != "%s"', $_, $r->{$_}, $row->{$_})) for qw(state ddd lat lon);
} continue {
    ++$i;
}

done_testing(3 + $i * 5);
