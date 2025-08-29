#!/usr/bin/env perl

use strict;
use warnings;
use JSON::MaybeXS;
use File::Slurp;

my $cover_db = 'cover_db/cover.json';
my $output   = 'cover_html/index.html';

# Read and decode coverage data
my $json_text = read_file($cover_db);
my $data = decode_json($json_text);

my $coverage_pct = 0;
if (my $total_info = $data->{summary}{Total}) {
    $coverage_pct = int($total_info->{total}{percentage} // 0);
}

# Start HTML
my $html = <<"HTML";
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Coverage Report</title>
  <style>
    body { font-family: sans-serif; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    .low { background-color: #fdd; }
    .med { background-color: #ffd; }
    .high { background-color: #dfd; }
    .badges img { margin-right: 10px; }
  </style>
</head>
<body>
<div class="badges">
  <a href="https://github.com/nigelhorne/SEO-Inspector">
    <img src="https://img.shields.io/github/stars/nigelhorne/SEO-Inspector?style=social" alt="GitHub stars">
  </a>
  <img src="https://img.shields.io/badge/coverage-${coverage_pct}%25-${coverage_pct > 80 ? 'brightgreen' : $coverage_pct > 50 ? 'yellow' : 'red'}" alt="Coverage badge">
</div>
<h1>Coverage Report</h1>
<table>
  <tr><th>File</th><th>Stmt</th><th>Branch</th><th>Cond</th><th>Sub</th><th>Total</th></tr>
HTML

# Add rows
for my $file (sort keys %{$data->{summary}}) {
	next if $file eq 'Total';  # Skip the aggregate row

	my $info = $data->{summary}{$file};
	my $html_file = $file;
	$html_file =~ s|/|-|g;         # Convert path separators to hyphens
	$html_file =~ s|\.pm$|-pm|;    # Replace .pm with -pm
	$html_file =~ s|\.pl$|-pl|;    # Optional: handle .pl files too

	$html_file .= '.html';

	my $total = $info->{total}{percentage} // 0;
	my $class = $total > 80 ? 'high' : $total > 50 ? 'med' : 'low';

	$html .= sprintf(
		qq{<tr class="%s"><td><a href="%s">%s</a></td><td>%.1f</td><td>%.1f</td><td>%.1f</td><td>%.1f</td><td>%.1f</td></tr>\n},
		$class, $html_file, $file,
		$info->{statement}{percentage} // 0,
		$info->{branch}{percentage}    // 0,
		$info->{condition}{percentage} // 0,
		$info->{subroutine}{percentage} // 0,
		$total
	);
}

# Add totals row
if (my $total_info = $data->{summary}{Total}) {
	my $total_pct = $total_info->{total}{percentage} // 0;
	my $class = $total_pct > 80 ? 'high' : $total_pct > 50 ? 'med' : 'low';

	$html .= sprintf(
		qq{<tr class="%s"><td><strong>Total</strong></td><td>%.1f</td><td>%.1f</td><td>%.1f</td><td>%.1f</td><td><strong>%.1f</strong></td></tr>\n},
		$class,
		$total_info->{statement}{percentage} // 0,
		$total_info->{branch}{percentage}    // 0,
		$total_info->{condition}{percentage} // 0,
		$total_info->{subroutine}{percentage} // 0,
		$total_pct
	);
}

$html .= <<'HTML';
</table>
<footer>
  <p>Project: <a href="https://github.com/nigelhorne/SEO-Inspector">SEO-Inspector</a></p>
</footer>
</body>
</html>
HTML

# Write to index.html
write_file($output, $html);
