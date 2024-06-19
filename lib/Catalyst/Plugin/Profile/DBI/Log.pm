# ABSTRACT: Capture queries executed during a Catalyst route with DBI::Log
package Catalyst::Plugin::Profile::DBI::Log;
BEGIN {
  $Catalyst::Plugin::Profile::DBI::Log::VERSION = '0.01';
}
use Moose::Role;
use namespace::autoclean;
 
use CatalystX::InjectComponent;
use Data::UUID;
use DateTime;
use DDP;
use Path::Tiny;

# Load DBI::Log, but point it at /dev/null to start with; we'll give it a
# new filehandle at the beginning of each request.
use DBI::Log timing => 1, trace => 1, format => 'json', file => '/dev/null';


# Ick - find a better way to pass this around than a global var!
my $dbilog_output_dir;

after 'setup_finalize' => sub {
    my $self = shift;

    my $conf = $self->config->{'Plugin::Profile::DBI::Log'} || {};
    $dbilog_output_dir = $conf->{dbilog_out_dir} || 'dbilog_output';

    if (!-d $dbilog_output_dir) {
        $self->log->debug("Creating DBI::Log output dir $dbilog_output_dir");
        Path::Tiny::path($dbilog_output_dir)->mkpath;
    } else {
        $self->log->debug("OK, using DBI::Log output dir $dbilog_output_dir");
    }
};
 
after 'setup_components' => sub {
    my $class = shift;
    $class->log->debug("Inject controller into $class");
    CatalystX::InjectComponent->inject(
        into => $class,
        component => 'Catalyst::Plugin::Profile::DBI::Log::Controller::ControlProfiling',
        as => 'Controller::DBI::Log'
    );
};

# Start a profile run when a request begins...
# FIXME: is this the best hook?  Want the Catalyst equivalent of a Dancer
# `before` hook.  `prepare_body` looks like a reasonable "we've read the
# request from the network, we're about to handle it" point.
after 'prepare_body' => sub {
    my $c = shift;

    # We want to name all profile outputs safely and usefully, encoding
    # the request method, path, and timestamp, and a random number for some
    # uniqueness.
    my $path = $c->request->method . '_' . ($c->request->path || '/');
    $path =~ s{/}{_s_}g;
    $path =~ s{[^a-z0-9]}{_}gi;
    $path .= "_t_" . DateTime->now->strftime('%Y-%m-%d_%H:%M:%S');
    $path .= substr Data::UUID->new->create_str, 0, 8;
    $path = Path::Tiny::path($dbilog_output_dir, $path);
    open my $dbilog_fh, ">", $path
        or $c->log->debug("Can't open $path to write - $!");
    $DBI::Log::opts{fh} = $dbilog_fh;
};


# And finalise it when the request is finished
after 'finalize_body' => sub {
    my $c = shift;
    $c->log->debug("finalize_body fired, stop profiling");
    # Do we need to do anything here?  The filehandle we're using will get
    # reset on next request, is there much point in us doing anything
    # specific here, besides maybe just making sure it's been flushed?
    # FIXME: what about seeing if we actually logged any queries to the
    # file - if it's zero-sized, there's no point it existing and we could
    # nuke it?
    $DBI::Log::opts{fh}->flush();

};


1;
