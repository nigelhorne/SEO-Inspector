package SEO::Inspector;

use strict;
use warnings;

use Carp;
use Mojo::UserAgent;
use Mojo::URL;
use Module::Pluggable require => 1, search_path => 'SEO::Inspector::Plugin';

=head1 NAME

SEO::Inspector - Run SEO checks on HTML or URLs

=head1 SYNOPSIS

  use SEO::Inspector;

  my $inspector = SEO::Inspector->new(url => 'https://example.com');

  # Run plugins
  my $html = '<html><body>......</body></html>';
  my $plugin_results = $inspector->check_html($html);

  # Run built-in checks
  my $builtin_results = $inspector->run_all($html);

  # Check a single URL and get all results
  my $all_results = $inspector->check_url('https://example.com');

=head1 DESCRIPTION

SEO::Inspector provides:

=over 4

=item * Built-in SEO checks: title, meta description, canonical link, robots meta, viewport, H1 presence, word count, image alt text

=item * Plugin system: dynamically load modules under SEO::Inspector::Plugin namespace

=item * Methods to check HTML strings or fetch and analyze a URL

=back

=head1 METHODS

=head2 new(%args)

Create a new inspector object. Accepts optional C<url> and C<plugin_dirs> arguments.
If C<plugin_dirs> isn't given, it tries hard to find the right place.

=cut

our $VERSION = '0.01';

# -------------------------------
# Constructor
# -------------------------------
sub new {
	my ($class, %args) = @_;
	my $self = bless { %args }, $class;

	$self->{ua} ||= Mojo::UserAgent->new();
	$self->{plugins} ||= {};

	$self->load_plugins();

	return $self;
}

# -------------------------------
# Load plugins from SEO::Inspector::Plugin namespace
# -------------------------------
sub load_plugins {
	my $self = $_[0];

	for my $plugin ($self->plugins()) {
		my $key = lc($plugin =~ s/.*:://r);
		$self->{plugins}{$key} = $plugin->new();
	}
    if($self->{plugin_dirs}) {
	    for my $dir (@{$self->{plugin_dirs}}) {
		local @INC = ($dir, @INC);

		my $finder = Module::Pluggable::Object->new(
		    search_path => ['SEO::Inspector::Plugin'],
		    require     => 1,
		    instantiate => 'new',
		);

		for my $plugin ($finder->plugins) {
			my $key = lc(ref($plugin) =~ s/.*:://r);
			$self->{plugins}{$key} = $plugin;
		}
	    }
	}
}

# -------------------------------
# Fetch HTML from URL or object default
# -------------------------------
sub _fetch_html {
	my ($self, $url) = @_;
	$url //= $self->{url};
	croak 'URL missing' unless $url;

	my $res = $self->{ua}->get($url)->result;
	if ($res->is_error) {
		croak 'Fetch failed: ', $res->message();
	}
	return $res->body;
}

# -------------------------------
# Run a single plugin or built-in check
# -------------------------------
sub check {
    my ($self, $check_name, $html) = @_;
    $html //= $self->_fetch_html();

    my %dispatch = (
        title            => \&_check_title,
        meta_description => \&_check_meta_description,
        canonical        => \&_check_canonical,
        robots_meta      => \&_check_robots_meta,
        viewport         => \&_check_viewport,
        h1_presence      => \&_check_h1_presence,
        word_count       => \&_check_word_count,
        links_alt_text   => \&_check_links_alt_text,
	check_structured_data => \&_check_structured_data,
	check_headings	=> \&_check_headings,
	check_links	=> \&_check_links,
    );

    # built-in checks
    if (exists $dispatch{$check_name}) {
        return $dispatch{$check_name}->($self, $html);
    } else {
    	croak "Unknown check $check_name";
	}

    # plugin checks
    if (exists $self->{plugins}{$check_name}) {
        my $plugin = $self->{plugins}{$check_name};
        return $plugin->run($html);
    }

    return { name => $check_name, status => 'unknown', notes => '' };
}

# -------------------------------
# Run all built-in checks
# -------------------------------
sub run_all
{
	my ($self, $html) = @_;
	$html //= $self->_fetch_html();

	my %results;
	for my $check (qw(
		title meta_description canonical robots_meta viewport h1_presence word_count links_alt_text
		check_structured_data check_headings check_links
	)) {
		$results{$check} = $self->check($check, $html);
	}

	return \%results;
}

# -------------------------------
# Run all plugins on HTML
# -------------------------------
sub check_html {
    my ($self, $html) = @_;
    $html //= $self->_fetch_html();
    my %results;

    for my $key (keys %{ $self->{plugins} }) {
        my $plugin = $self->{plugins}{$key};
        $results{$key} = $plugin->run($html);
    }

    return \%results;
}

# -------------------------------
# Run URL: fetch and check
# -------------------------------
sub check_url {
    my ($self, $url) = @_;
    $url //= $self->{url};
    croak "URL missing" unless $url;

    my $html = $self->_fetch_html($url);

    my $plugin_results  = $self->check_html($html);
    my $builtin_results = $self->run_all($html);

    # merge all results
    my %results = (%$plugin_results, %$builtin_results, _html => $html);
    return \%results;
}

# -------------------------------
# Built-in check implementations
# -------------------------------
sub _check_title {
    my ($self, $html) = @_;
    if ($html =~ /<title>(.*?)<\/title>/is) {
        my $title = $1;
        return { name => 'Title', status => length($title) ? 'ok' : 'error', notes => length($title) ? 'title present' : 'missing title' };
    }
    return { name => 'Title', status => 'error', notes => 'missing title' };
}

sub _check_meta_description {
    my ($self, $html) = @_;
    if ($html =~ /<meta\s+name=["']description["']\s+content=["'](.*?)["']/is) {
        my $desc = $1;
        return { name => 'Meta Description', status => 'ok', notes => 'meta description present' };
    }
    return { name => 'Meta Description', status => 'warn', notes => 'missing meta description' };
}

sub _check_canonical {
    my ($self, $html) = @_;
    if ($html =~ /<link\s+rel=["']canonical["']\s+href=["'](.*?)["']/is) {
        return { name => 'Canonical', status => 'ok', notes => 'canonical link present' };
    }
    return { name => 'Canonical', status => 'warn', notes => 'missing canonical link' };
}

sub _check_robots_meta {
    my ($self, $html) = @_;
    if ($html =~ /<meta\s+name=["']robots["']\s+content=["'](.*?)["']/is) {
        return { name => 'Robots Meta', status => 'ok', notes => 'robots meta present' };
    }
    return { name => 'Robots Meta', status => 'warn', notes => 'missing robots meta' };
}

sub _check_viewport {
    my ($self, $html) = @_;
    if ($html =~ /<meta\s+name=["']viewport["']\s+content=["'](.*?)["']/is) {
        return { name => 'Viewport', status => 'ok', notes => 'viewport meta present' };
    }
    return { name => 'Viewport', status => 'warn', notes => 'missing viewport meta' };
}

sub _check_h1_presence {
    my ($self, $html) = @_;
    if ($html =~ /<h1\b[^>]*>(.*?)<\/h1>/is) {
        return { name => 'H1 Presence', status => 'ok', notes => 'h1 tag present' };
    }
    return { name => 'H1 Presence', status => 'warn', notes => 'missing h1' };
}

sub _check_word_count {
    my ($self, $html) = @_;
    my $text = $html;
    $text =~ s/<[^>]+>//g;
    my $words = scalar split /\s+/, $text;
    return { name => 'Word Count', status => $words > 0 ? 'ok' : 'warn', notes => "$words words" };
}

sub _check_links_alt_text {
    my ($self, $html) = @_;
    my @missing;
    while ($html =~ /<img\b(.*?)>/gis) {
        my $attr = $1;
        push @missing, $1 unless $attr =~ /alt=/i;
    }
    return { name => 'Links Alt Text', status => @missing ? 'warn' : 'ok', notes => @missing ? scalar(@missing) . " images missing alt" : 'all images have alt' };
}

sub _check_structured_data {
    my ($self, $html) = @_;

    my @jsonld = ($html =~ /<script\b[^>]*type=["']application\/ld\+json["'][^>]*>(.*?)<\/script>/gis);

    return {
        name   => 'Structured Data',
        status => @jsonld ? 'ok' : 'warn',
        notes  => @jsonld ? scalar(@jsonld) . " JSON-LD block(s) found" : 'no structured data found',
    };
}

sub _check_headings {
    my ($self, $html) = @_;

    my %counts;
    while ($html =~ /<(h[1-6])\b[^>]*>/gi) {
        $counts{lc $1}++;
    }

    my $summary = join ', ', map { "$_: $counts{$_}" } sort keys %counts;

    return {
        name   => 'Headings',
        status => %counts ? 'ok' : 'warn',
        notes  => %counts ? $summary : 'no headings found',
    };
}


sub _check_links {
    my ($self, $html) = @_;

    my $base_host;
    if ($self->{url} && $self->{url} =~ m{^https?://}i) {
        $base_host = Mojo::URL->new($self->{url})->host;
    }

    my ($total, $internal, $external, $badtext) = (0,0,0,0);

    # common "bad" link text patterns (exact match or just punctuation around)
    my $bad_rx = qr/^(?:click\s*here|read\s*more|more|link|here|details)$/i;

    while ($html =~ m{<a\b([^>]*)>(.*?)</a>}gis) {
        my $attrs = $1;
        my $text  = $2 // '';

        $total++;

        # get href (prefer quoted values)
        my ($href) = $attrs =~ /\bhref\s*=\s*"(.*?)"/i;
        $href //= ($attrs =~ /\bhref\s*=\s*'(.*?)'/i ? $1 : undef);
        $href //= ($attrs =~ /\bhref\s*=\s*([^\s>]+)/i ? $1 : undef);

        # classify internal vs external
        if (defined $href && $href =~ m{^\s*https?://}i) {
            # attempt to compare host
            my ($host) = $href =~ m{^\s*https?://([^/:\s]+)}i;
            if (defined $base_host && defined $host) {
                if (lc $host eq lc $base_host) {
                    $internal++;
                } else {
                    $external++;
                }
            } else {
                # no base host to compare; treat as external if absolute URL
                $external++;
            }
        } else {
            # relative URL or fragment or mailto/etc -> treat as internal
            $internal++;
        }

        # normalize visible text: strip tags, trim whitespace, collapse spaces
        $text =~ s/<[^>]+>//g;
        $text =~ s/^\s+|\s+$//g;
        $text =~ s/\s+/ /g;

        # check for bad link text (exact-ish)
        if ($text =~ $bad_rx) {
            $badtext++;
        }
    }

    my $status = ($external || $badtext) ? 'warn' : ($total ? 'ok' : 'warn');

    my $notes;
    if ($total) {
        $notes = sprintf("%d total (%d internal, %d external). %d link(s) with poor anchor text",
                         $total, $internal, $external, $badtext);
    } else {
        $notes = 'no links found';
    }

    return {
        name   => 'Links',
        status => $status,
        notes  => $notes,
    };
}

1;

__END__

=head2 load_plugins

Automatically loads plugins from C<SEO::Inspector::Plugin> namespace.

=head2 check($check_name, $html)

Run a single built-in check or plugin on provided HTML (or fetch from object URL if HTML not provided).

=head2 run_all($html)

Run all built-in checks on HTML (or object URL).

=head2 check_html($html)

Run all loaded plugins on HTML.

=head2 check_url($url)

Fetch the URL and run all plugins and built-in checks.

=head1 SEE ALSO

L<https://nigelhorne.github.io/SEO-Inspector/covertage>

=cut
