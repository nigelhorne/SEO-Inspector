use strict;
use warnings;

use File::Path qw/make_path/;
use File::Spec;
use File::Temp qw/tempdir/;
use Test::Most;

use SEO::Inspector;

# --- Create a temporary directory for the plugin ---
my $tmpdir  = tempdir(CLEANUP => 1);
my $plugdir = File::Spec->catdir($tmpdir, qw/SEO Inspector Plugin/);
make_path($plugdir);

# --- Write the fake plugin module ---
my $plugin_file = File::Spec->catfile($plugdir, 'FakeCheck.pm');
open my $fh, '>', $plugin_file or die "Cannot write $plugin_file: $!";
print $fh <<'EOF';
package SEO::Inspector::Plugin::FakeCheck;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub run {
    my ($self, $html) = @_;
    return {
        name   => 'FakeCheck',
        status => 'ok',
        notes  => 'plugin ran',
    };
}

1;
EOF
close $fh;

# --- Add temporary directory to @INC at runtime ---
require lib;
lib->import($tmpdir);

# --- Subclass SEO::Inspector to allow HTML-only checks ---
{
    package SEO::Inspector::Testable;
    use parent 'SEO::Inspector';

    # Run all loaded plugins against provided HTML
    sub check_html {
        my ($self, $html) = @_;
        my @report;
        for my $plugin_name (keys %{ $self->{plugins} }) {
            my $plugin = $self->{plugins}{$plugin_name};
            push @report, $plugin->run($html);
        }
        return { map { lc($_->{name}) => $_ } @report };  # keyed by lowercase
    }
}

# --- Initialize inspector ---
my $inspector = SEO::Inspector::Testable->new;

# --- Explicitly load the plugin ---
ok($inspector->load_plugin('FakeCheck'), 'FakeCheck plugin loaded');

# --- Verify plugin registration ---
ok(exists $inspector->{plugins}{'fakecheck'}, 'Plugin registered in plugins hash');

# --- Run plugin on dummy HTML ---
my $html   = '<html><head><title>Test</title></head><body>Content</body></html>';
my $result = $inspector->check_html($html);

# --- Assertions ---
cmp_deeply($result, {
   'fakecheck' => {
     'name' => 'FakeCheck',
     'notes' => 'plugin ran',
     'status' => 'ok'
   }
 });

done_testing();
