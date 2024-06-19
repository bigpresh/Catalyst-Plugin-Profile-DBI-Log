#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Catalyst::Profile::DBI::Log' ) || print "Bail out!\n";
}

diag( "Testing Catalyst::Profile::DBI::Log $Catalyst::Profile::DBI::Log::VERSION, Perl $], $^X" );
