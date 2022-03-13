use strict;
use warnings;
package Mojolicious::Plugin::OpenAPI::Modern;
# vim: set ts=8 sts=2 sw=2 tw=100 et :
# ABSTRACT: Mojolicious plugin providing access to an OpenAPI document and parser
# KEYWORDS: validation evaluation JSON Schema OpenAPI Swagger HTTP request response

our $VERSION = '0.002';

use 5.020;
use if "$]" >= 5.022, experimental => 're_strict';
no if "$]" >= 5.031009, feature => 'indirect';
no if "$]" >= 5.033001, feature => 'multidimensional';
no if "$]" >= 5.033006, feature => 'bareword_filehandles';
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Feature::Compat::Try;
use YAML::PP;
use Path::Tiny;
use JSON::MaybeXS;
use Safe::Isa;
use OpenAPI::Modern 0.022;
use namespace::clean;

sub register ($self, $app, $config) {
  my $stash = Mojo::Util::_stash(openapi => $app);

  try {
    my $schema;
    if (exists $config->{schema}) {
      $schema = $config->{schema};
    }
    elsif (exists $config->{document_filename}) {
      if ($config->{document_filename} =~ /\.ya?ml$/) {
        $schema = YAML::PP->new(boolean => 'JSON::PP')->load_file($config->{document_filename}),
      }
      elsif ($config->{document_filename} =~ /\.json$/) {
        $schema = JSON::MaybeXS->new(allow_nonref => 1, utf8 => 1)->decode(
          path($config->{document_filename})->slurp_raw);
      }
      else {
        die 'Unsupported file format in filename: ', $config->{document_filename};
      }
    }
    else {
      die 'missing config: one of schema, filename';
    }

    my $openapi = OpenAPI::Modern->new(
      openapi_uri    => $config->{document_filename} // '',
      openapi_schema => $schema,
    );

    # leave room for other keys in our localized stash
    $stash->{openapi} = $openapi;
  }
  catch ($e) {
    die 'Cannot load OpenAPI document: ', $e;
  }

  $app->helper(openapi => sub ($c) { $stash->{openapi} });
}

1;
__END__

=pod

=head1 SYNOPSIS

  $app->config({
    openapi => {
      document_filename => 'data/openapi.yaml',
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
L<OpenAPI::Modern/openapi_schema>.

=head2 document_filename

A filename indicating from where to load the OpenAPI document. Supports YAML and json file formats.

=head1 METHODS

=head2 register

Instantiates an L<OpenAPI::Modern> object and provides an accessor to it.

=head1 HELPERS

These methods are made available on the C<$c> object (the invocant of all controller methods,
and therefore other helpers).

=for stopwords openapi

=head2 openapi

The L<OpenAPI::Modern> object.

=head1 SEE ALSO

=for :list
* L<OpenAPI::Modern>
* L<JSON::Schema::Modern::Document::OpenAPI>
* L<JSON::Schema::Modern>
* L<https://json-schema.org>
* L<https://www.openapis.org/>
* L<https://oai.github.io/Documentation/>
* L<https://spec.openapis.org/oas/v3.1.0>

=head1 SUPPORT

You can also find me on the L<JSON Schema Slack server|https://json-schema.slack.com> and L<OpenAPI Slack
server|https://open-api.slack.com>, which are also great resources for finding help.

=cut
