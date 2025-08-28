package SEO::Inspector;

use strict;
use warnings;
use Mojo::UserAgent;

our $VERSION = '0.01';

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        url  => $args{url},
        ua   => Mojo::UserAgent->new,
        html => undef,
    }, $class;
    return $self;
}

sub _fetch_html {
    my ($self) = @_;
    return $self->{html} if $self->{html};

    my $res = $self->{ua}->get($self->{url})->result;
    die "Fetch failed: " . $res->message unless $res->is_success;

    $self->{html} = $res->body;
    return $self->{html};
}

sub run_all {
    my ($self) = @_;
    my @checks = qw(
        title
        meta_description
        canonical
        robots_meta
        viewport
        h1_presence
        word_count
        links_alt_text
    );

    return [ map { $self->check($_) } @checks ];
}

sub check {
    my ($self, $check_name) = @_;
    my $html = $self->_fetch_html;

    my %dispatch = (
        title           => \&_check_title,
        meta_description=> \&_check_meta_description,
        canonical       => \&_check_canonical,
        robots_meta     => \&_check_robots_meta,
        viewport        => \&_check_viewport,
        h1_presence     => \&_check_h1_presence,
        word_count      => \&_check_word_count,
        links_alt_text  => \&_check_links_alt_text,
    );

    return { name => $check_name, status => 'unknown', notes => '' }
        unless exists $dispatch{$check_name};

    return $dispatch{$check_name}->($self, $html);
}

### --- Individual Checks ---

sub _check_title {
    my ($self, $html) = @_;
    if ($html =~ m{<title>(.*?)</title>}is) {
        my $title = $1;
        return { name=>'title', status=>'ok', notes=>$title };
    }
    return { name=>'title', status=>'missing' };
}

sub _check_meta_description {
    my ($self, $html) = @_;
    if ($html =~ m{<meta\s+name=["']description["']\s+content=["'](.*?)["']}is) {
        return { name=>'meta_description', status=>'ok', notes=>$1 };
    }
    return { name=>'meta_description', status=>'missing' };
}

sub _check_canonical {
    my ($self, $html) = @_;
    if ($html =~ m{<link\s+rel=["']canonical["']\s+href=["'](.*?)["']}is) {
        return { name=>'canonical', status=>'ok', notes=>$1 };
    }
    return { name=>'canonical', status=>'missing' };
}

sub _check_robots_meta {
    my ($self, $html) = @_;
    if ($html =~ m{<meta\s+name=["']robots["']\s+content=["'](.*?)["']}is) {
        return { name=>'robots_meta', status=>'ok', notes=>$1 };
    }
    return { name=>'robots_meta', status=>'missing' };
}

sub _check_viewport {
    my ($self, $html) = @_;
    if ($html =~ m{<meta\s+name=["']viewport["']}is) {
        return { name=>'viewport', status=>'ok' };
    }
    return { name=>'viewport', status=>'missing' };
}

sub _check_h1_presence {
    my ($self, $html) = @_;
    if ($html =~ m{<h1[^>]*>(.*?)</h1>}is) {
        return { name=>'h1_presence', status=>'ok', notes=>$1 };
    }
    return { name=>'h1_presence', status=>'missing' };
}

sub _check_word_count {
    my ($self, $html) = @_;
    my $text = $html;
    $text =~ s/<[^>]+>//g;  # strip tags
    my $count = scalar split /\s+/, $text;
    return { name=>'word_count', status=>$count, notes=>"Words: $count" };
}

sub _check_links_alt_text {
    my ($self, $html) = @_;
    my @missing;
    while ($html =~ m{<img[^>]*>}gis) {
        my $img = $&;
        push @missing, $img unless $img =~ /alt=/i;
    }
    return {
        name   => 'links_alt_text',
        status => @missing ? 'missing' : 'ok',
        notes  => @missing ? scalar(@missing) . " images without alt" : '',
    };
}

1;
