use strictures 2;
package Mojolicious::Plugin::OpenAPI::Modern;
# vim: set ts=8 sts=2 sw=2 tw=100 et :
# ABSTRACT: Mojolicious plugin providing access to an OpenAPI document and parser
# KEYWORDS: validation evaluation JSON Schema OpenAPI Swagger HTTP request response

our $VERSION = '0.014';

use 5.020;
use if "$]" >= 5.022, experimental => 're_strict';
no if "$]" >= 5.031009, feature => 'indirect';
no if "$]" >= 5.033001, feature => 'multidimensional';
no if "$]" >= 5.033006, feature => 'bareword_filehandles';
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Feature::Compat::Try;
use YAML::PP;
use Path::Tiny;
use Mojo::JSON 'decode_json';
use Safe::Isa;
use OpenAPI::Modern 0.037;
use namespace::clean;

# we store data in two places: on the app (persistent storage, for the OpenAPI::Modern object
# itself) and in the controller stash: per-request data like the path info and extracted path items.

# the first is $app->openapi or $c->openapi
# the second is $c->stash('openapi') which will be initialized to {} on first use.
sub register ($self, $app, $config) {
  my $stash = Mojo::Util::_stash(openapi => $app);

  try {
    my $openapi = $config->{openapi_obj} // OpenAPI::Modern->new(_process_configs($config));

    # leave room for other keys in our localized stash
    $stash->{openapi} = $openapi;
  }
  catch ($e) {
    die 'Cannot load OpenAPI document: ', $e;
  }

  $app->helper(openapi => sub ($) { $stash->{openapi} });

  $app->helper(validate_request => \&_validate_request);
  $app->helper(validate_response => \&_validate_response);

  $app->hook(after_dispatch => sub ($c) {
    $c->res->on(finish => sub ($res) { $config->{after_response}->($c) });
  }) if $config->{after_response};
}

# converts a config hash into values suitable for constructing an OpenAPI::Modern object
sub _process_configs ($config) {
  my $schema;
  if (exists $config->{schema}) {
    $schema = $config->{schema};
  }
  elsif (exists $config->{document_filename}) {
    if ($config->{document_filename} =~ /\.ya?ml$/) {
      $schema = YAML::PP->new(boolean => 'JSON::PP')->load_file($config->{document_filename}),
    }
    elsif ($config->{document_filename} =~ /\.json$/) {
      $schema = decode_json(path($config->{document_filename})->slurp_raw);
    }
    else {
      die 'Unsupported file format in filename: ', $config->{document_filename};
    }
  }
  else {
    die 'missing config: one of schema, filename';
  }

  return {
    openapi_uri    => $config->{document_filename} // '',
    openapi_schema => $schema,
  };
}

sub _validate_request ($c) {
  my $options = $c->stash->{openapi} //= {};
  return $c->openapi->validate_request($c->req, $options);
}

sub _validate_response ($c) {
  my $options = $c->stash->{openapi} //= {};
  local $options->{request} = $c->req;
  return $c->openapi->validate_response($c->res, $options);
}

1;
__END__

=pod

=for stopwords openapi operationId subref

=head1 SYNOPSIS

  $app->config({
    openapi => {
      document_filename => 'data/openapi.yaml',
      after_response => sub ($c) { ... },
    },
    ...
  });

  $app->plugin('OpenAPI::Modern', $app->config->{openapi});

  # in a controller...
  my $result = $c->openapi->validate_request($c->req);

=head1 DESCRIPTION

This L<Mojolicious> plugin makes an L<OpenAPI::Modern> object available to the application.

There are many features to come.

=head1 CONFIGURATION OPTIONS

=head2 schema

The literal, unblessed Perl data structure containing the OpenAPI document. See
L<OpenAPI::Modern/openapi_schema>; passed to the L<OpenAPI::Modern> constructor.
Only used if L</openapi_obj> is not provided.

=head2 document_filename

A filename indicating from where to load the OpenAPI document. Supports YAML and json file formats.
Only used if L</schema> is not provided; also passed to the L<OpenAPI::Modern> constructor as
C<openapi_uri>. Only used if L</openapi_obj> is not provided.

=head2 openapi_obj

An L<OpenAPI::Modern> object to use

=head2 after_response

A subref which runs after the response has been finalized, to allow you to perform validation on it.
You B<must not> mutate the response here, nor swap it out for a different response, so use this only
for telemetry and logging.

  my $after_response = sub ($c) {
    my $result = $c->validate_response;
    if ($result->valid) {
      $c->log->debug('response is valid');
    }
    else {
      # see JSON::Schema::Modern::Result for different output formats
      $c->log->error("response is invalid:\n", $result);
    }
  };

=head1 METHODS

=head2 register

Instantiates an L<OpenAPI::Modern> object and provides an accessor to it.

=head1 HELPERS

These methods are made available on the C<$c> object (the invocant of all controller methods,
and therefore other helpers).

=head2 openapi

The L<OpenAPI::Modern> object; it holds your OpenAPI specification and is reused between requests.

=head2 validate_request

  my $result = $c->openapi->validate_request;

Passes C<< $c->req >> to L<OpenAPI::Modern/validate_request> and returns a
L<JSON::Schema::Modern::Result> object.

Note that the matching L<Mojo::Routes::Route> object for this request is I<not> used to find the
OpenAPI path-item that corresponds to this request: only information in the request URI itself is
used (although some information in the route may be used in future features).

You might want to define an C<under> route action that calls C<validate_request> and short-circuits
with an HTTP 400 response on validation failure.

=head2 validate_response

  my $result = $c->openapi->validate_response;

Passes C<< $c->res >> and C<< $c->req >> to L<OpenAPI::Modern/validate_response> and returns a
L<JSON::Schema::Modern::Result> object.

As this can only be called in the parts of the dispatch flow where the response has already been
rendered and finalized, a hook has been set up for you; you can access it by providing a subref to the
L</after_response> configuration value:

  $app->config->{openapi}{after_response} //= sub ($c) {
    my $result = $c->validate_response;
    # ... do something with the validation result
  };

Note that the matching L<Mojo::Routes::Route> object for this request is I<not> used to find the
OpenAPI path-item that corresponds to this request and response: only information in the request URI
itself is used (although some information in the route may be used in future features).

=head1 STASH VALUES

This plugin stores all its data under the C<openapi> hashref, e.g.:

  my $operation_id = $c->stash->{openapi}{operation_id};

Keys starting with underscore are for I<internal use only> and should not be relied upon to behave
consistently across release versions. Values that may be used by controllers and templates are:

=for :list
* C<path_template>: Set by the first call to L</validate_request> or L</validate_response>.
  A string representing the request URI, with placeholders in braces (e.g. C</pets/{petId}>); see
  L<https://spec.openapis.org/oas/v3.1.0#paths-object>.
* C<path_captures>: Set by the first call to L</validate_request> or L</validate_response>.
  A hashref mapping placeholders in the path to their actual values in the request URI.
* C<operation_id>: Set by the first call to L</validate_request> or L</validate_response>.
  Contains the corresponding
  L<operationId|https://swagger.io/docs/specification/paths-and-operations/#operationid> of the
  current endpoint.
* C<method>: Set by the first call to L</validate_request> or L</validate_response>.
  The HTTP method used by the request, lower-cased.

=head1 SEE ALSO

=for :list
* L<OpenAPI::Modern>
* L<Test::Mojo::Role::OpenAPI::Modern>
* L<JSON::Schema::Modern::Document::OpenAPI>
* L<JSON::Schema::Modern>
* L<https://json-schema.org>
* L<https://www.openapis.org/>
* L<https://learn.openapis.org/>
* L<https://spec.openapis.org/oas/v3.1.0>

=head1 SUPPORT

You can also find me on the L<JSON Schema Slack server|https://json-schema.slack.com> and
L<OpenAPI Slack server|https://open-api.slack.com>, which are also great resources for finding help.

=cut
