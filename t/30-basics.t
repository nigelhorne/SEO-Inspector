use strict;
use warnings;
use Test::Most;

use SEO::Inspector;

my $inspector = SEO::Inspector->new(
    url => 'https://example.com/',
);

isa_ok($inspector, 'SEO::Inspector');

can_ok($inspector, qw(new run_all check));

done_testing;
