#!perl -T
use strict;

use Test::More tests => 1;

BEGIN {
    use_ok('Geo::CEP');
}

diag("Testing Geo::CEP $Geo::CEP::VERSION, Perl $], $^X");
