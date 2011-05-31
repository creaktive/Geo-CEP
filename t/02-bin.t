#!perl
use strict;

use Config;
use Test::More tests => 1;

local $/ = undef;
my $buf = <DATA>;

ok(`$Config{perlpath} bin/cep2city 12420-010` eq $buf, 'bin script');

__DATA__
cep       	12420010
city      	Pindamonhangaba
ddd       	12
lat       	-22.9166667
lon       	-45.4666667
state     	SP
state_long	São Paulo

