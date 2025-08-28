package SEO::Inspector::Plugin::TitleCheck;
use strict;
use warnings;
use HTML::TreeBuilder;

sub new { bless {}, shift }

sub name { 'TitleCheck' }

sub run {
    my ($self, $html) = @_;
    my $tree = HTML::TreeBuilder->new_from_content($html);
    my $title = $tree->look_down(_tag => 'title');
    $tree->delete;

    if ($title && length($title->as_text) > 0) {
        return { status => 'ok', notes => 'title present' };
    }
    return { status => 'error', notes => 'missing title' };
}

1;
