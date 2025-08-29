#!/usr/bin/env perl

use strict;
use warnings;
use JSON;
use File::Slurp;

my $cover_db = 'cover_db/coverage.json';
my $output   = 'cover_html/index.html';

# Read and decode coverage data
my $json_text = read_file($cover_db);
my $data = decode_json($json_text);

# Start HTML
my $html = <<'HTML';
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
  </style>
</head>
<body>
<h1>Coverage Report</h1>
<table>
  <tr><th>File</th><th>Stmt</th><th>Branch</th><th>Cond</th><th>Sub</th><th>Total</th></tr>
HTML

# Add rows
for my $file (sort keys %{$data->{files}}) {
    my $info = $data->{files}{$file};
    my $html_file = $file;
    $html_file =~ s|/|_|g;
    $html_file .= '.html';

    my $total = $info->{total};
    my $class = $total > 80 ? 'high' : $total > 50 ? 'med' : 'low';

    $html .= sprintf(
        qq{<tr class="%s"><td><a href="%s">%s</a></td><td>%.1f</td><td>%.1f</td><td>%.1f</td><td>%.1f</td><td>%.1f</td></tr>\n},
        $class, $html_file, $file,
        $info->{stmt}, $info->{branch}, $info->{condition}, $info->{subroutine}, $total
    );
}

# Close HTML
$html .= <<'HTML';
</table>
</body>
</html>
HTML

# Write to index.html
write_file($output, $html);
