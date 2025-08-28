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

`SEO::Inspector` is a lightweight Perl module for running
basic SEO (Search Engine Optimization) checks against a web page.

It is designed for web developers, SEO analysts, and site owners
who want to quickly validate on-page elements without requiring
heavy external tools.

Pages are fetched using [Mojo::UserAgent](https://metacpan.org/pod/Mojo%3A%3AUserAgent), and results are
returned in a structured hash format, making it easy to integrate
with dashboards, reporting tools, or CI pipelines.

# METHODS

## new

    my $inspector = SEO::Inspector->new(url => $url);

Creates a new inspector for the given URL.

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

# RETURN VALUES

Each check returns a hashref like:

    {
        name   => 'title',
        status => 'ok',
        notes  => 'Example Domain',
    }

# DEPENDENCIES

- [Mojo::UserAgent](https://metacpan.org/pod/Mojo%3A%3AUserAgent)
- Perl 5.10+

# SEE ALSO

[Mojolicious](https://metacpan.org/pod/Mojolicious), [LWP::UserAgent](https://metacpan.org/pod/LWP%3A%3AUserAgent), [HTML::TreeBuilder](https://metacpan.org/pod/HTML%3A%3ATreeBuilder)

# AUTHOR

Nigel Horne <njh@bandsman.co.uk>

# COPYRIGHT AND LICENSE

Copyright (C) 2025 Nigel Horne

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
