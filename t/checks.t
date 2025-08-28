use strict;
use warnings;
use Test::Most;

use SEO::Inspector;

# Fake inspector with injected HTML
{
    package SEO::Inspector::Testable;
    our @ISA = ('SEO::Inspector');
    sub set_html {
        my ($self, $html) = @_;
        $self->{html} = $html;
    }
}

my $inspector = SEO::Inspector::Testable->new(url => 'http://fake/');

my $html = <<'HTML';
<!DOCTYPE html>
<html>
<head>
  <title>Example Domain</title>
  <meta name="description" content="This is an example.">
  <link rel="canonical" href="https://example.com/">
  <meta name="robots" content="index,follow">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
  <h1>Example Heading</h1>
  <p>This is some example content with enough words to count.</p>
  <img src="logo.png" alt="Example logo">
  <img src="missing.png">
</body>
</html>
HTML

$inspector->set_html($html);

# Run all checks
my $report = $inspector->run_all;

cmp_deeply(
    [ map { $_->{name} } @$report ],
    superbagof(qw(title meta_description canonical robots_meta viewport h1_presence word_count links_alt_text)),
    "All expected checks run"
);

# Individual checks
my $title = $inspector->check('title');
is $title->{status}, 'ok', 'Title present';
like $title->{notes}, qr/Example Domain/, 'Title extracted';

my $meta = $inspector->check('meta_description');
is $meta->{status}, 'ok', 'Meta description present';

my $canon = $inspector->check('canonical');
is $canon->{status}, 'ok', 'Canonical present';
like $canon->{notes}, qr{https://example.com/}, 'Canonical URL matches';

my $h1 = $inspector->check('h1_presence');
is $h1->{status}, 'ok', 'H1 present';
like $h1->{notes}, qr/Example Heading/, 'H1 text extracted';

my $words = $inspector->check('word_count');
cmp_ok $words->{status}, '>', 5, 'Word count above threshold';

my $alts = $inspector->check('links_alt_text');
is $alts->{status}, 'missing', 'Found missing alt attribute';
like $alts->{notes}, qr/1 images without alt/, 'Count reported correctly';

done_testing;
