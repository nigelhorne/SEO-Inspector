package SEO::Inspector;

use strict;
use warnings;
use Mojo::UserAgent;

our $VERSION = '0.01';

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

C<SEO::Inspector> is a lightweight Perl module for running 
basic SEO (Search Engine Optimization) checks against a web page.

It is designed for web developers, SEO analysts, and site owners 
who want to quickly validate on-page elements without requiring 
heavy external tools.

Pages are fetched using L<Mojo::UserAgent>, and results are 
returned in a structured hash format, making it easy to integrate 
with dashboards, reporting tools, or CI pipelines.

=head1 METHODS

=head2 new

  my $inspector = SEO::Inspector->new(url => $url);

Creates a new inspector for the given URL.

=head2 run_all

  my $report = $inspector->run_all;

Runs the default suite of SEO checks and returns an arrayref of results.  
Each result is a hashref with keys:

=over 4

=item * C<name> — the check name

=item * C<status> — result status (C<ok>, C<missing>, or a numeric/string value)

=item * C<notes> — optional notes or extracted values

=back

=head2 check

  my $result = $inspector->check('title');

Runs a single named check. Returns a hashref as above.

=head1 CHECKS

The following checks are currently implemented:

=over 4

=item * C<title> — Ensures a <title> tag is present.

=item * C<meta_description> — Looks for a meta description tag.

=item * C<canonical> — Validates a canonical link tag.

=item * C<robots_meta> — Checks for a robots meta directive.

=item * C<viewport> — Checks for a responsive viewport meta tag.

=item * C<h1_presence> — Ensures at least one <h1> element exists.

=item * C<word_count> — Counts visible words on the page.

=item * C<links_alt_text> — Ensures all <img> tags have alt attributes.

=back

=head1 RETURN VALUES

Each check returns a hashref like:

  {
      name   => 'title',
      status => 'ok',
      notes  => 'Example Domain',
  }

=head1 DEPENDENCIES

=over 4

=item * L<Mojo::UserAgent>

=item * Perl 5.10+

=back

=head1 SEE ALSO

L<Mojolicious>, L<LWP::UserAgent>, L<HTML::TreeBuilder>

=head1 AUTHOR

Nigel Horne E<lt>njh@bandsman.co.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 Nigel Horne

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
