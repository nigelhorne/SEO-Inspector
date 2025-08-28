# NAME

SEO::Inspector - Run SEO checks on HTML or URLs

# SYNOPSIS

    use SEO::Inspector;

    my $inspector = SEO::Inspector->new(url => 'https://example.com');

    # Run plugins
    my $html = '<html><body>......</body></html>';
    my $plugin_results = $inspector->check_html($html);

    # Run built-in checks
    my $builtin_results = $inspector->run_all($html);

    # Check a single URL and get all results
    my $all_results = $inspector->check_url('https://example.com');

# DESCRIPTION

SEO::Inspector provides:

- Built-in SEO checks: title, meta description, canonical link, robots meta, viewport, H1 presence, word count, image alt text
- Plugin system: dynamically load modules under SEO::Inspector::Plugin namespace
- Methods to check HTML strings or fetch and analyze a URL

# METHODS

## new(%args)

Create a new inspector object. Accepts optional `url` argument.

## load\_plugins

Automatically loads plugins from `SEO::Inspector::Plugin` namespace.

## check($check\_name, $html)

Run a single built-in check or plugin on provided HTML (or fetch from object URL if HTML not provided).

## run\_all($html)

Run all built-in checks on HTML (or object URL).

## check\_html($html)

Run all loaded plugins on HTML.

## check\_url($url)

Fetch the URL and run all plugins and built-in checks.
