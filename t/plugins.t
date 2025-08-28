use strict;
use warnings;
use Test::Most;
use lib 'lib';

use SEO::Inspector;

# --- Create a fake plugin as a coderef ---
my $fake_plugin = sub {
    my ($self, $html) = @_;
    return { name => 'fakecheck', status => 'ok', notes => 'plugin ran' };
};

# --- Initialize SEO::Inspector with dummy HTML ---
{
    package SEO::Inspector::Testable;
    our @ISA = ('SEO::Inspector');

    # Override _fetch_html to prevent live HTTP requests
    sub _fetch_html { return "<html><body><h1>Test</h1></body></html>"; }
}

my $inspector = SEO::Inspector::Testable->new(url => 'http://fake/');

# Manually register the fake plugin
$inspector->{plugins}{FakeCheck} = $fake_plugin;

# Verify that plugin is registered
ok(exists $inspector->{plugins}{'FakeCheck'}, 'Plugin registered in plugins hash');

# Run plugin-specific check
my $result = $inspector->check('FakeCheck');
isa_ok($result, 'HASH');
is($result->{name}, 'fakecheck', 'Check name matches plugin');
is($result->{status}, 'ok', 'Check status is ok');
like($result->{notes}, qr/plugin ran/, 'Check notes from plugin');

# Run all checks including plugin
my $report = $inspector->run_all;
ok( (grep { $_->{name} eq 'fakecheck' } @$report) ? 1 : 0, 'Plugin appears in run_all report' );

done_testing;
