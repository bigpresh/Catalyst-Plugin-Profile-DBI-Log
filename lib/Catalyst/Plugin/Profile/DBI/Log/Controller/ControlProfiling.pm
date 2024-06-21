# ABSTRACT: Control profiling within your application
package Catalyst::Plugin::Profile::DBI::Log::Controller::ControlProfiling;
BEGIN {
  $Catalyst::Plugin::Profile::DBI::Log::Controller::ControlProfiling::VERSION = '0.02';
}
use Moose;
use Path::Tiny qw(path);
use namespace::autoclean;

use File::stat;
use HTML::Entities;
 
BEGIN { extends 'Catalyst::Controller' }
 
#use Devel::DBI::Log;

# FIXME: how am I going to share this from the Catalyst::Plugin plugin code
# to this controller code nicely?  Need both to get default values and be
# able to override in app config
my $dbilog_output_dir = 'dbilog_output';

=for fuck's sake

sub auto : Private {
    my ($self, $c) = @_;
    $c->log->debug("auto action called");
}

=cut

sub globalregex :Regexp(.+) {
    my ($self, $c) = @_;
    $c->log->debug("globalregex fired");
    return 1;
}

sub index : Local {
    my ($self, $c) = @_;
    # ICK ICK ICK, get this in a nice template
    my $html = <<HTML;
<h1>DBI::Log management</h1>

<style>
table {
  border-collapse: collapse;
  font-size: 11px;
  font-family: Source Code Pro, monospace;
}
table td {
    padding: 3px;
}
</style>

<h2>Profiled requests...</h2>

<table border="1" cellspacing="5">
<tr>
<th>Method</th>
<th>Path</th>
<th>Total query time</th>
<th>Longest query</th>
<th>Query count</th>
<th>Datetime</th>
<th>IP</th>
<th>View</th>
</tr>
HTML

    opendir my $outdir, $dbilog_output_dir
        or die "Failed to opendir $dbilog_output_dir - $!";
    my @files = grep { $_ !~ /^(\.|html)/ } readdir $outdir;
    file:
    for my $file (
        grep { 
            -s path($dbilog_output_dir, $_) 
        } sort {
            (stat path($dbilog_output_dir, $b))->ctime
            <=>
            (stat path($dbilog_output_dir, $a))->ctime
        } @files
    ) {
        my $title = $file;
        $title =~ s{_s_}{/}g;
        my ($method, $path ,$timestamp, $uuid) = split '_', $title, 4;
        my $stats = get_stats(path($dbilog_output_dir, $file));

        # We delete logs for requests that didn't have any queries at the
        # end of the request, but seemingly that doesn't /always/ happen
        # - so bail now if we don't have any queries to report.
        next file unless $stats->{query_count};

        my $datetime = scalar localtime( (stat path($dbilog_output_dir, $file))->ctime);
        my $path = format_path($stats->{path_query});

        $html .= <<ROW;
<tr><td>$stats->{method}</td><td>$path</td>
<td>$stats->{total_query_time}s</td>
<td>$stats->{slowest_query}s</td>
<td>$stats->{query_count}</td>
<td>$datetime</td>
<td>$stats->{ip}</td>
<td><a href="/dbi/log/show/$file">View</a></td>
</tr>
ROW
    }

    $html .= "</table>";

    # FIXME - in our app, the default view tries to render a template
    # named after the URL path.  How do we stop that?
    $c->response->body($html);
    $c->response->status(200);
    #$c->detach;
}


# Turn URL path into HTML to display the path part before the query more
# prominently, and potentially truncate long query strings. 
sub format_path {
    my $in = shift;
    my ($path, $query) = split /\?/, $in, 2;
    my $out = qq{<span class="path" style="font-weight:bold">$path</span>};
    if ($query) {
        # check if too long
        my $reveal_js;
        my $display_query = $query;
        if (length $query > 100) {
            $display_query = substr($query, 0, 100) . "...";
            # FIXME probably need to be careful here in case the query contains
            # quotes.  Just encode entities first?
            $reveal_js = qq{onclick="this.textContent = '$query'" title="Click to display all"};
        }
        $display_query = HTML::Entities::encode_entities($display_query);
        
        $out .= qq{?<span class="querystring" $reveal_js>$display_query</span>};
    }
    return $out;

}


sub get_stats {
    my $file = shift;
    my @json_lines = path($file)->lines;

    my %stats;
    # The file is line-delimited JSON, where each line is a separate
    # JSON object, so we need to read each line as JSON separately.
    # The first line is our metadata describing the HTTP request which was
    # being processed.
    my $metadata_json = shift @json_lines;
    %stats = %{ JSON::from_json($metadata_json) };

    for my $line (@json_lines) {
        my $line_data = JSON::from_json($line);
        $stats{query_count}++;
        $stats{total_query_time} += $line_data->{time_taken};
        $stats{slowest_query} = $line_data->{time_taken} 
            if $line_data->{time_taken} > $stats{slowest_query};
    }
    return \%stats;
    
}

#sub show : Local {
#    my ($self, $c) = @_;
#sub show :Local :Regex('show/(.+)') {
sub show :Local Args(1) {
    my ($self, $c, $profile) = @_;

    my ($method, $path ,$timestamp, $uuid) = split '_', $profile, 4;

    my $profile_path = Path::Tiny::path(
        $dbilog_output_dir,
        $profile
    );
    my $datetime = scalar localtime($profile_path->stat->ctime);

    my $stats = get_stats($profile_path);

my $html = <<HTML;

<script type="text/javascript" src="https://unpkg.com/sql-formatter\@latest/dist/sql-formatter.min.js"></script>
<script type="text/javascript" src="https://unpkg.com/jquery"></script>

<h1>DBI log for request $method $path at $datetime</h1>

<p>Total time querying DB: $stats->{total_query_time}s</p>


<table border="1">
<tr>
<th>Query</th>
<th>Took</th>
</tr>
HTML

    for my $json_line ($profile_path->lines) {
        my $data = JSON::from_json($json_line);
        $html .= <<ROW;
<tr>
<td><pre class="query">$data->{query}</pre></td>
<td>$data->{time_taken}</td>
</tr>
ROW
    }

    $html .= <<'END';
</table>

<script>
$('.query').each(function (i) {
    let formatted = sqlFormatter.format($(this).text(), { language: 'postgresql' });
    console.log(`Format ${ $(this).text() } to ${ formatted }`);
    $(this).text( formatted );
});
</script>
END

    $c->response->body($html);


}


 
1;
 
 
__END__
