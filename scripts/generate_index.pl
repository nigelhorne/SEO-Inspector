#!/usr/bin/env perl

use strict;
use warnings;

# safer, modern modules
use JSON::MaybeXS qw(decode_json encode_json);
use Path::Tiny qw(path);
use File::Glob qw(bsd_glob);
use POSIX qw(strftime);
use File::stat;
use Try::Tiny;

# constants for paths
my $cover_db = 'cover_db/cover.json';
my $output   = 'cover_html/index.html';

# --- Load coverage data safely ---
my $json_text = try {
	path($cover_db)->slurp_utf8;
} catch {
	die "Failed to read coverage DB $cover_db: $_";
};

my $data = try {
	decode_json($json_text);
} catch {
	die "Failed to decode JSON in $cover_db: $_";
};

# --- Coverage percentage + badge color ---
my $coverage_pct  = 0;
my $badge_color   = 'red';
if ( my $total_info = $data->{summary}{Total} ) {
	$coverage_pct = int( $total_info->{total}{percentage} // 0 );
	$badge_color  = $coverage_pct > 80 ? 'brightgreen'
				  : $coverage_pct > 50 ? 'yellow'
				  : 'red';
}

my $coverage_badge_url
	= "https://img.shields.io/badge/coverage-${coverage_pct}%25-${badge_color}";

# --- Start HTML ---
my @html;	# build in array, join later
push @html, <<"HTML";
<!DOCTYPE html>
<html>
<head>
<title>SEO::Inspector Coverage Report</title>
<style>
/* consider moving CSS into separate file for maintainability */
body { font-family: sans-serif; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
th { background-color: #f2f2f2; }
.low { background-color: #fdd; }
.med { background-color: #ffd; }
.high { background-color: #dfd; }
.badges img { margin-right: 10px; }
.disabled-icon { opacity: 0.4; cursor: default; }
.icon-link { text-decoration: none; }
.icon-link:hover { opacity: 0.7; cursor: pointer; }
.coverage-badge {
	padding: 2px 6px;
	border-radius: 4px;
	font-weight: bold;
	color: white;
	font-size: 0.9em;
}
.badge-good { background-color: #4CAF50; }
.badge-warn { background-color: #FFC107; }
.badge-bad { background-color: #F44336; }
.summary-row { font-weight: bold; background-color: #f0f0f0; }
td.positive { color: green; font-weight: bold; }
td.negative { color: red; font-weight: bold; }
td.neutral { color: gray; }
</style>
</head>
<body>
<div class="badges">
	<a href="https://github.com/nigelhorne/SEO-Inspector">
		<img src="https://img.shields.io/github/stars/nigelhorne/SEO-Inspector?style=social" alt="GitHub stars">
	</a>
	<img src="$coverage_badge_url" alt="Coverage badge">
</div>
<h1>SEO::Inspector</h1><h2>Coverage Report</h2>
<table>
<tr><th>File</th><th>Stmt</th><th>Branch</th><th>Cond</th><th>Sub</th><th>Total</th><th>&Delta;</th></tr>
HTML

# --- Load previous snapshot for deltas ---
my @history = sort { $a cmp $b } bsd_glob("coverage_history/*.json");
my $prev_data;
if (@history) {
	my $prev_file = $history[-1];	# most recent snapshot
	try {
		$prev_data = decode_json( path($prev_file)->slurp_utf8 );
	} catch {
		warn "Failed to parse previous coverage file $prev_file: $_";
	};
}

my %deltas;
if ($prev_data) {
	for my $file ( keys %{ $data->{summary} } ) {
		next if $file eq 'Total';
		my $curr  = $data->{summary}{$file}{total}{percentage} // 0;
		my $prev  = $prev_data->{summary}{$file}{total}{percentage} // 0;
		my $delta = $curr - $prev;	# keep numeric
		$deltas{$file} = $delta;
	}
}

# --- Git commit SHA (safe open instead of backticks) ---
my $commit_sha = '';
{
	open my $fh, '-|', qw(git rev-parse HEAD)
		or die "Can't run git rev-parse: $!";
	chomp( $commit_sha = <$fh> // '' );
	close $fh;
}
die "Failed to get commit sha" unless $commit_sha;

my $github_base
	= "https://github.com/nigelhorne/SEO-Inspector/blob/$commit_sha/";

# --- Table rows ---
my ( $total_files, $total_coverage, $low_coverage_count ) = ( 0, 0, 0 );
for my $file ( sort keys %{ $data->{summary} } ) {
	next if $file eq 'Total';

	my $info = $data->{summary}{$file};

	# sanitize filename for HTML link
	my $html_file = $file;
	$html_file =~ s|/|-|g;
	$html_file =~ s|\.pm$|-pm|;
	$html_file =~ s|\.pl$|-pl|;
	$html_file .= '.html';

	my $total = $info->{total}{percentage} // 0;
	$total_files++;
	$total_coverage	 += $total;
	$low_coverage_count++ if $total < 70;

	my $badge_class = $total >= 90 ? 'badge-good'
		: $total >= 70 ? 'badge-warn'
		: 'badge-bad';
	my $tooltip = $total >= 90 ? 'Excellent coverage'
		: $total >= 70 ? 'Moderate coverage'
		: 'Needs improvement';
	my $row_class = $total >= 90 ? 'high'
		: $total >= 70 ? 'med'
		: 'low';

	my $badge_html
		= sprintf( '<span class="coverage-badge %s" title="%s">%.1f%%</span>',
		$badge_class, $tooltip, $total );

	# delta info
	my $delta_html;
	if ( exists $deltas{$file} ) {
		my $delta	   = $deltas{$file};
		my $delta_class = $delta > 0 ? 'positive'
			: $delta < 0 ? 'negative'
			: 'neutral';
		my $delta_icon = $delta > 0 ? '&#9650;'
			: $delta < 0 ? '&#9660;'
			: '&#9679;';
		my $prev_pct
			= $prev_data->{summary}{$file}{total}{percentage} // 0;
		$delta_html = sprintf(
			'<td class="%s" title="Previous: %.1f%%">%s %.1f%%</td>',
			$delta_class, $prev_pct, $delta_icon, abs($delta)
		);
	}
	else {
		$delta_html
			= '<td class="neutral" title="No previous data">&#9679;</td>';
	}

	my $source_url   = $github_base . $file;
	my $has_coverage = (
		defined $info->{statement}{percentage}
		|| defined $info->{branch}{percentage}
		|| defined $info->{condition}{percentage}
		|| defined $info->{subroutine}{percentage}
	);

	my $source_link = $has_coverage
		? sprintf(
		'<a href="%s" class="icon-link" title="View source on GitHub">&#128269;</a>',
		$source_url
		)
		: '<span class="disabled-icon" title="No coverage data">&#128269;</span>';

	push @html, sprintf(
		qq{<tr class="%s"><td><a href="%s" title="View coverage line by line">%s</a> %s</td><td>%.1f</td><td>%.1f</td><td>%.1f</td><td>%.1f</td><td>%s</td>%s</tr>\n},
		$row_class, $html_file, $file, $source_link,
		$info->{statement}{percentage} // 0,
		$info->{branch}{percentage}	// 0,
		$info->{condition}{percentage} // 0,
		$info->{subroutine}{percentage} // 0,
		$badge_html, $delta_html
	);
}

# --- Summary row ---
my $avg_coverage = $total_files ? int( $total_coverage / $total_files ) : 0;
push @html, sprintf(
	qq{<tr class="summary-row"><td colspan="2"><strong>Summary</strong></td><td colspan="2">%d files</td><td colspan="3">Avg: %d%%, Low: %d</td></tr>\n},
	$total_files, $avg_coverage, $low_coverage_count
);

# --- Totals row ---
if ( my $total_info = $data->{summary}{Total} ) {
	my $total_pct = $total_info->{total}{percentage} // 0;
	my $class	 = $total_pct > 80 ? 'high'
		: $total_pct > 50 ? 'med'
		: 'low';
	push @html, sprintf(
		qq{<tr class="%s"><td><strong>Total</strong></td><td>%.1f</td><td>%.1f</td><td>%.1f</td><td>%.1f</td><td colspan="2"><strong>%.1f</strong></td></tr>\n},
		$class,
		$total_info->{statement}{percentage} // 0,
		$total_info->{branch}{percentage}	// 0,
		$total_info->{condition}{percentage} // 0,
		$total_info->{subroutine}{percentage} // 0,
		$total_pct
	);
}

# --- Timestamp for footer ---
my $timestamp = 'Unknown';
if ( my $stat = stat($cover_db) ) {
	$timestamp = strftime( "%Y-%m-%d %H:%M:%S", localtime( $stat->mtime ) );
}

my $commit_url = "https://github.com/nigelhorne/SEO-Inspector/commit/$commit_sha";
my $short_sha  = substr( $commit_sha, 0, 7 );

push @html, "</table>\n";

# TODO: refactor history and chart logic similarly, applying the same principles:
# - safe JSON reads
# - clamp splice counts
# - check regex matches
# - avoid backticks for git
# - factor repeated code into subs

# --- Footer ---
push @html, <<"HTML";
<footer>
<p>Project: <a href="https://github.com/nigelhorne/SEO-Inspector">SEO-Inspector</a></p>
<p><em>Last updated: $timestamp - <a href="$commit_url">commit <code>$short_sha</code></a></em></p>
</footer>
</body>
</html>
HTML

# --- Write output atomically ---
path($output)->parent->mkpath;
path($output)->spew_utf8( join "", @html );
