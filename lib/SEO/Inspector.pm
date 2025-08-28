package SEO::Inspector;

use strict;
use warnings;
use Mojo::UserAgent;

our $VERSION = '0.02';

=head1 NAME

SEO::Inspector - Perform common SEO checks on web pages

=head1 SYNOPSIS

  use SEO::Inspector;

  my $inspector = SEO::Inspector->new(
      url => 'https://example.com/',
  );

  # Run all checks
  my $report = $inspector->run_all;

  foreach my $check (@$report) {
      printf "%-20s : %s\n", $check->{name}, $check->{status};
      print "  Notes: $check->{notes}\n" if $check->{notes};
  }

  # Run a single check
  my $meta = $inspector->check('meta_description');
  print "Meta description: $meta->{status}\n";

=head1 DESCRIPTION

C<SEO::Inspector> is a lightweight module for running
basic SEO (Search Engine Optimization) checks against a web page.

It is designed for web developers, SEO analysts, and site owners
who want to quickly validate on-page elements without requiring
heavy external tools.

Pages are fetched using L<Mojo::UserAgent>, and results are
returned in a structured hash format, making it easy to integrate
with dashboards, reporting tools, or CI pipelines.

=head1 CHECKS

The following checks are currently implemented:

=over 4

=item * C<title> - Ensures a <title> tag is present.

=item * C<meta_description> - Looks for a meta description tag.

=item * C<canonical> - Validates a canonical link tag.

=item * C<robots_meta> - Checks for a robots meta directive.

=item * C<viewport> - Checks for a responsive viewport meta tag.

=item * C<h1_presence> - Ensures at least one <h1> element exists.

=item * C<word_count> - Counts visible words on the page.

=item * C<links_alt_text> - Ensures all <img> tags have alt attributes.

=back

=head1 PLUGIN SYSTEM

C<SEO::Inspector> supports a simple plugin mechanism to add custom checks.

A plugin is just a Perl module under the C<SEO::Inspector::Plugin::>
namespace that provides a C<run($self, $html)> method.

For example:

  package SEO::Inspector::Plugin::SocialTags;

  sub run {
      my ($self, $html) = @_;
      if ($html =~ m{<meta\s+property=["']og:title["']}i) {
          return { name=>'socialtags', status=>'ok' };
      }
      return { name=>'socialtags', status=>'missing' };
  }

  1;

To enable plugins:

  my $inspector = SEO::Inspector->new(url => $url);
  $inspector->load_plugin('SocialTags');

  my $result = $inspector->check('socialtags');

This allows developers to extend C<SEO::Inspector> without modifying the core module.

Plugins should inherit from L<SEO::Inspector::Plugin> and implement:

=over 4

=item * new - constructor

=item * name - plugin name

=item * run($html) - returns a hashref with keys C<status> and C<notes>

=back

=head1 RETURN VALUES

Each check returns a hashref like:

  {
      name   => 'title',
      status => 'ok',
      notes  => 'Example Domain',
  }

=head1 METHODS

=head2 new

  my $inspector = SEO::Inspector->new(url => $url);

Creates a new inspector for the given URL.
Automatically loads all installed plugins.

=cut

sub new {
	my ($class, %args) = @_;
	my $self = bless {
		url     => $args{url},
		ua      => $args{'ua'} || Mojo::UserAgent->new(timeout => 10),
		plugins => {},   # plugin name -> coderef
	}, $class;

	$self->load_plugins();

	return $self;
}

=head2 load_plugins

  $inspector->load_plugins;

Load all available SEO::Inspector::Plugin::* modules dynamically.  
Normally called automatically by C<new>, but can be invoked manually if you install new plugins at runtime.

=cut

# --- Load all Plugin::* modules dynamically
sub load_plugins {
    my ($self) = @_;
    no strict 'refs';
    for my $mod (@{ $INC{'SEO/Inspector/Plugin'} || [] }) {
        eval {
            require_module($mod);
            $self->{plugins}->{ lc($mod =~ s/.*:://r) } = $mod->new;
        };
        warn "Failed to load plugin $mod: $@" if $@;
    }
}

=head2 check_html

  my $results = $inspector->check_html($html);

Run all loaded plugins against a given HTML string.  
Returns a hashref where keys are plugin identifiers and values are hashrefs with:

=over 4

=item * name - Plugin name

=item * status - Check status (e.g., 'ok', 'warn', 'error')

=item * notes - Any notes from the plugin

=back

=cut

# --- Run all plugins against a HTML string
sub check_html {
    my ($self, $html) = @_;
    my %results;
    for my $key (keys %{ $self->{plugins} }) {
        my $plugin = $self->{plugins}{$key};
        my $res = $plugin->run($html);
        $results{$key} = {
            name   => $plugin->name,
            status => $res->{status} // 'unknown',
            notes  => $res->{notes}  // '',
        };
    }
    return \%results;
}

=head2 check_url

  my $results = $inspector->check_url($url);

Fetch the given URL and run all plugins on its HTML content.  
Returns the same hashref structure as C<check_html>.  
If fetching fails, returns a hashref containing an C<error> key with the HTTP status message.

=cut

# --- Fetch a URL and analyze HTML
sub check_url {
	my ($self, $url) = @_;
	my $res = $self->{ua}->get($url);

	return { error => $res->status_line } unless $res->is_success;
	return $self->check_html($res->decoded_content);
}

=head2 render_report

  my $text = $inspector->render_report($results);
  my $json = $inspector->render_report($results, 'json');

Format plugin results for output.  

=over 4

=item * $results - hashref returned from C<check_html> or C<check_url>

=item * $format - optional, 'text' (default) or 'json'

=back

Returns a string containing the formatted report.

=cut

# --- Render a report in JSON or text
sub render_report {
    my ($self, $results, $format) = @_;
    $format ||= 'text';

    if ($format eq 'json') {
        return encode_json($results);
    } else {
        my $out = "";
        for my $key (sort keys %$results) {
            my $r = $results->{$key};
            $out .= sprintf("[%s] %s: %s\n", $r->{status}, $r->{name}, $r->{notes});
        }
        return $out;
    }
}

sub _fetch_html
{
	my $self = $_[0];

	return $self->{html} if $self->{html};

	my $res = $self->{ua}->get($self->{url})->result;
	die 'Fetch failed: ', $res->message() unless $res->is_success;

	$self->{html} = $res->body();
	return $self->{html};
}

=head2 run_all

  my $report = $inspector->run_all;

Runs the default suite of SEO checks and returns an arrayref of results.
Each result is a hashref with keys:

=over 4

=item * C<name> - the check name

=item * C<status> - result status (C<ok>, C<missing>, or a numeric/string value)

=item * C<notes> - optional notes or extracted values

=back

=cut

sub run_all
{
	my $self = $_[0];

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

	# include plugin checks
	push @checks, keys %{ $self->{plugins} };

	return [ map { $self->check($_) } @checks ];
}

=head2 check

  my $result = $inspector->check('title');

Runs a single named check. Returns a hashref as above.

=cut

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

	# built-in checks
	if (exists $dispatch{$check_name}) {
		return $dispatch{$check_name}->($self, $html);
	}

	# plugin checks
	if (exists $self->{plugins}{$check_name}) {
		my $plugin = $self->{plugins}{$check_name};
		return $plugin->($self, $html);
	}

	return { name => $check_name, status => 'unknown', notes => '' };
}

### --- Plugin System ---

=head2 load_plugin

  $inspector->load_plugin('SocialTags');

Loads a plugin module from the C<SEO::Inspector::Plugin::> namespace.
The plugin must provide a C<run($self, $html)> method that returns
a hashref in the same format as built-in checks.

=cut

sub load_plugin {
	my ($self, $plugin_name) = @_;

	my $full_class = "SEO::Inspector::Plugin::$plugin_name";
	eval "require $full_class";
	die "Failed to load plugin $full_class: $@" if $@;

	my $runner;
	if ($full_class->can('run')) {
		$runner = sub { $full_class->run(@_) };
	} else {
		die "Plugin $full_class must implement a run() method";
	}

	# Register plugin check
	$self->{plugins}{ lc $plugin_name } = $full_class->new();

	return 1;
}

### --- Built-in Checks ---

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
        notes  => @missing ? scalar(@missing) . ' images without alt' : '',
    };
}

1;

__END__

=head1 AUTHOR

Nigel Horne, C<< <njh at nigelhorne.com> >>

=head1 SUPPORT

This module is provided as-is without any warranty.

=head1 SEE ALSO

L<Mojolicious>, L<LWP::UserAgent>, L<HTML::TreeBuilder>

=head2 COVERAGE REPORT

L<https://nigelhorne.github.io/SEO-Inspector/coverage/index.html>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 Nigel Horne

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
