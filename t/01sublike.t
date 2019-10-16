#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Keyword::SubLike;

my @results;

BEGIN {
   push @results, "BEGIN";
}

BEGIN {
   sublike foo => sub {
      my ( $name, $parenstring, $code ) = @_;

      push @results, "$name - $parenstring";

      $code->();
   };
}

push @results, "runtime";

foo mything(whatever, I, want) {
   push @results, "code of mything";
}

push @results, "eof";

is_deeply( \@results,
   [ "BEGIN",
     "mything - (whatever, I, want)",
     "code of mything",
     "runtime",
     "eof" ],
   'Results are accumulated correctly' );

done_testing;
