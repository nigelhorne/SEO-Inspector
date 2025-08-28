# NAME

SEO::Inspector - Perform common SEO checks on web pages

# SYNOPSIS

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

# DESCRIPTION

`SEO::Inspector` is a lightweight module for running
basic SEO (Search Engine Optimization) checks against a web page.

It is designed for web developers, SEO analysts, and site owners
who want to quickly validate on-page elements without requiring
heavy external tools.

Pages are fetched using [Mojo::UserAgent](https://metacpan.org/pod/Mojo%3A%3AUserAgent), and results are
returned in a structured hash format, making it easy to integrate
with dashboards, reporting tools, or CI pipelines.

# CHECKS

The following checks are currently implemented:

- `title` - Ensures a &lt;title> tag is present.
- `meta_description` - Looks for a meta description tag.
- `canonical` - Validates a canonical link tag.
- `robots_meta` - Checks for a robots meta directive.
- `viewport` - Checks for a responsive viewport meta tag.
- `h1_presence` - Ensures at least one &lt;h1> element exists.
- `word_count` - Counts visible words on the page.
- `links_alt_text` - Ensures all &lt;img> tags have alt attributes.

# PLUGIN SYSTEM

`SEO::Inspector` supports a simple plugin mechanism to add custom checks.

A plugin is just a Perl module under the `SEO::Inspector::Plugin::`
namespace that provides a `run($self, $html)` method.

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

This allows developers to extend `SEO::Inspector` without modifying the core module.

Plugins should inherit from [SEO::Inspector::Plugin](https://metacpan.org/pod/SEO%3A%3AInspector%3A%3APlugin) and implement:

- new - constructor
- name - plugin name
- run($html) - returns a hashref with keys `status` and `notes`

# RETURN VALUES

Each check returns a hashref like:

    {
        name   => 'title',
        status => 'ok',
        notes  => 'Example Domain',
    }

# METHODS

## new

    my $inspector = SEO::Inspector->new(url => $url);

Creates a new inspector for the given URL.
Automatically loads all installed plugins.

## load\_plugins

    $inspector->load_plugins;

Load all available SEO::Inspector::Plugin::\* modules dynamically.  
Normally called automatically by `new`, but can be invoked manually if you install new plugins at runtime.

## check\_html

    my $results = $inspector->check_html($html);

Run all loaded plugins against a given HTML string.  
Returns a hashref where keys are plugin identifiers and values are hashrefs with:

- name - Plugin name
- status - Check status (e.g., 'ok', 'warn', 'error')
- notes - Any notes from the plugin

## check\_url

    my $results = $inspector->check_url($url);

Fetch the given URL and run all plugins on its HTML content.  
Returns the same hashref structure as `check_html`.  
If fetching fails, returns a hashref containing an `error` key with the HTTP status message.

## render\_report

    my $text = $inspector->render_report($results);
    my $json = $inspector->render_report($results, 'json');

Format plugin results for output.  

- $results - hashref returned from `check_html` or `check_url`
- $format - optional, 'text' (default) or 'json'

Returns a string containing the formatted report.

## run\_all

    my $report = $inspector->run_all;

Runs the default suite of SEO checks and returns an arrayref of results.
Each result is a hashref with keys:

- `name` - the check name
- `status` - result status (`ok`, `missing`, or a numeric/string value)
- `notes` - optional notes or extracted values

## check

    my $result = $inspector->check('title');

Runs a single named check. Returns a hashref as above.

## load\_plugin

    $inspector->load_plugin('SocialTags');

Loads a plugin module from the `SEO::Inspector::Plugin::` namespace.
The plugin must provide a `run($self, $html)` method that returns
a hashref in the same format as built-in checks.

# AUTHOR

Nigel Horne, `<njh at nigelhorne.com>`

# SUPPORT

This module is provided as-is without any warranty.

# SEE ALSO

[Mojolicious](https://metacpan.org/pod/Mojolicious), [LWP::UserAgent](https://metacpan.org/pod/LWP%3A%3AUserAgent), [HTML::TreeBuilder](https://metacpan.org/pod/HTML%3A%3ATreeBuilder)

## COVERAGE REPORT

[https://nigelhorne.github.io/SEO-Inspector/coverage/index.html](https://nigelhorne.github.io/SEO-Inspector/coverage/index.html)

# COPYRIGHT AND LICENSE

Copyright (C) 2025 Nigel Horne

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
