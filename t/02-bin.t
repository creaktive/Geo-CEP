#!perl
use strict;
use utf8;
use warnings qw(all);

use open qw(:locale);

use Test::More tests => 1;

local $/ = undef;
is(qx($^X bin/cep2city 12420-010), <DATA>, 'bin script');

__DATA__
cep       	12420010
city      	Pindamonhangaba
ddd       	12
lat       	-22.9166667
lon       	-45.4666667
state     	SP
state_long	São Paulo

