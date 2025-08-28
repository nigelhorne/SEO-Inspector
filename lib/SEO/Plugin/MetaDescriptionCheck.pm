package SEO::Inspector::Plugin::MetaDescriptionCheck;
use strict;
use warnings;
use HTML::TreeBuilder;

sub new { bless {}, shift }

sub name { 'MetaDescriptionCheck' }

sub run {
    my ($self, $html) = @_;
    my $tree = HTML::TreeBuilder->new_from_content($html);
    my $meta = $tree->look_down(_tag => 'meta', name => 'description');
    $tree->delete;

    if ($meta && $meta->attr('content')) {
        return { status => 'ok', notes => 'meta description present' };
    }
    return { status => 'warn', notes => 'missing meta description' };
}

1;
