# NAME

Catalyst::Plugin::Profile::DBI::Log - per-request DB query logging & profiling

# SYNOPSIS

Load the plugin like any other Catalyst plugin e.g.

    use Catalyst qw(Profile::DBI::Log);

hit your app with some requests, then point your browser at `/dbi/log/index` 
and you'll see a list of HTTP requests handled, along with info on how many 
queries they ran and how long they spent waiting for the DB, with a clickable
link to view the actual queries and stack trace of where they came from.

For screenshots of the profiler in action, see the project website:
[https://bigpresh.github.io/Catalyst-Plugin-Profile-DBI-Log](https://bigpresh.github.io/Catalyst-Plugin-Profile-DBI-Log).

# DESCRIPTION

I needed a way to quickly and easily see, for each API route invocation (HTTP
request) my app handled,

- How many DB queries were performed
- How long we spent waiting for DB queries
- What the actual queries executed were and how long each took
- Where in our codebase those queries were performed

This plugin is designed to simplify just that.

When loaded, it arranges for [DBI::Log](https://metacpan.org/pod/DBI%3A%3ALog) to log all queries to log files,
while adding some metadata of our own to identify the HTTP request being
processed.  It adds a route handler to provide routes to list requests
profiled along with summary info (how many queries, how long spent waiting on
queries etc), and clickable links to view all the queries performed, and to
view a stack trace of where the query was performed from (to see easily what
part of your codebase triggered it).

# SEE ALSO

There are a couple of prior art examples which capture stats from DBIC
using [DBIx::Class::Storage::Statistics](https://metacpan.org/pod/DBIx%3A%3AClass%3A%3AStorage%3A%3AStatistics) such as [Catalyst::Plugin::DBIC::Profiler](https://metacpan.org/pod/Catalyst%3A%3APlugin%3A%3ADBIC%3A%3AProfiler)
but parts of one of our apps, for hairy legacy reasons also go direct to the
DB with DBI, so we needed to catch those too - and wanted a useful way to
see the list of profiled requests right in the browser.

The source code is available on GitHub:
[https://github.com/bigpresh/Catalyst-Plugin-Profile-DBI-Log](https://github.com/bigpresh/Catalyst-Plugin-Profile-DBI-Log).

Screenshots and an overview may be found on the project website:
[https://bigpresh.github.io/Catalyst-Plugin-Profile-DBI-Log](https://bigpresh.github.io/Catalyst-Plugin-Profile-DBI-Log).

- [DBI::Log](https://metacpan.org/pod/DBI%3A%3ALog)
- [Catalyst::Plugin::DBIC::Profiler](https://metacpan.org/pod/Catalyst%3A%3APlugin%3A%3ADBIC%3A%3AProfiler)
- [CatalystX::InjectComponent](https://metacpan.org/pod/CatalystX%3A%3AInjectComponent)

# SECURITY

This is a development tool.  It captures, records and serves up raw SQL queries
which may well contain sensitive information - e.g. parameters used to search
the DB, etc.  I would not recommend loading it on a production site or exposing
an app with it loaded to the Internet.

# AUTHOR

David Precious (BIGPRESH) `<davidp@preshweb.co.uk>`

# COPYRIGHT AND LICENCE

Copyright (C) 2024 by David Precious

This library is free software; you can redistribute it and/or modify it 
under the same terms as Perl itself.
