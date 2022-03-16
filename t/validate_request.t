# vim: set ts=8 sts=2 sw=2 tw=100 et :
use strict;
use warnings;
use 5.020;
use Test::More 0.88;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use experimental qw(signatures postderef);
use if "$]" >= 5.022, experimental => 're_strict';
no if "$]" >= 5.031009, feature => 'indirect';
no if "$]" >= 5.033001, feature => 'multidimensional';
no if "$]" >= 5.033006, feature => 'bareword_filehandles';
use open ':std', ':encoding(UTF-8)'; # force stdin, stdout, stderr into utf8
use Mojolicious::Plugin::OpenAPI::Modern;
use Path::Tiny;
use Test::Mojo;
use constant { true => JSON::PP::true, false => JSON::PP::false };
use JSON::Schema::Modern::Utilities 'jsonp';

use lib 't/lib';

my $openapi_preamble = {
  openapi => '3.1.0',
  info => {
    title => 'Test API with raw schema',
    version => '1.2.3',
  },
};

my $abs_uri = sub ($t) {
  Mojo::URL->new->host($t->tx->req->headers->host)->scheme('https');
};

subtest 'validate_request helper' => sub {
  my $t = Test::Mojo->new(
    'BasicApp',
    {
      openapi => {
        schema => YAML::PP->new(boolean => 'JSON::PP')->load_string(<<'YAML')} });
openapi: 3.1.0
info:
  title: Test API with raw schema
  version: 1.2.3
components:
  responses:
    validation_response:
      description: capture validation result
      content:
        application/json:
          schema:
            properties:
              stash:
                type: object
              result:
                properties:
                  valid:
                    type: boolean
                  errors:
                    type: array
                    items:
                      type: object
paths:
  /foo/{foo_id}:
    parameters:
    - name: foo_id
      in: path
      required: true
      schema:
        type: string
        pattern: ^[a-z]+$
    post:
      operationId: operation_foo
      requestBody:
        content:
          text/plain:
            schema:
              type: string
              pattern: ^[a-z]+$
      responses:
        200:
          $ref: '#/components/responses/validation_response'
        400:
          $ref: '#/components/responses/validation_response'
YAML

  $t->post_ok('/foo/hi/there')
    ->status_is(400, 'path_template cannot be found')
    ->json_is({
      stash => {
        method => 'post',
      },
      result => my $expected_result = {
        valid => false,
        errors => [
          {
            instanceLocation => '/request/uri/path',
            keywordLocation => jsonp(qw(/paths)),
            absoluteKeywordLocation => $t->$abs_uri->fragment('/paths')->to_string,
            error => 'no match found for URI path "/foo/hi/there"',
          },
        ],
      },
    });

  $t->get_ok('/foo/hi')
    ->status_is(400, 'wrong HTTP method')
    ->json_is({
      stash => {
        path_template => '/foo/{foo_id}',
        path_captures => { foo_id => 'hi' },
        method => 'get',
      },
      result => $expected_result = {
        valid => false,
        errors => [
          {
            instanceLocation => '/request/method',
            keywordLocation => jsonp(qw(/paths /foo/{foo_id} get)),
            absoluteKeywordLocation => $t->$abs_uri->fragment(jsonp(qw(/paths /foo/{foo_id} get)))->to_string,
            error => 'missing operation for HTTP method "get"',
          },
        ],
      },
    });

  $t->post_ok('/foo/123')
    ->status_is(400, 'path parameter will fail validation')
    ->json_is({
      stash => {
        method => 'post',
        operation_id => 'operation_foo',
        path_template => '/foo/{foo_id}',
        path_captures => { foo_id => '123' },
      },
      result => {
        valid => false,
        errors => [
          {
            instanceLocation => '/request/uri/path/foo_id',
            keywordLocation => jsonp(qw(/paths /foo/{foo_id} parameters 0 schema pattern)),
            absoluteKeywordLocation => $t->$abs_uri->fragment(jsonp(qw(/paths /foo/{foo_id} parameters 0 schema pattern))),
            error => 'pattern does not match',
          },
        ],
      },
    });

  $t->post_ok('/foo/hi', { 'Content-Type' => 'text/plain' }, '123')
    ->status_is(400, 'valid path; body does not match')
    ->json_is({
      stash => {
        method => 'post',
        operation_id => 'operation_foo',
        path_template => '/foo/{foo_id}',
        path_captures => { foo_id => 'hi' },
      },
      result => {
        valid => false,
        errors => [
          {
            instanceLocation => '/request/body',
            keywordLocation => jsonp(qw(/paths /foo/{foo_id} post requestBody content text/plain schema pattern)),
            absoluteKeywordLocation => $t->$abs_uri->fragment(jsonp(qw(/paths /foo/{foo_id} post requestBody content text/plain schema pattern))),
            error => 'pattern does not match',
          },
        ],
      },
    });

  $t->post_ok('/foo/hi', { 'Content-Type' => 'text/plain' }, 'hi')
    ->status_is(200, 'request is valid')
    ->json_is({
      stash => {
        method => 'post',
        operation_id => 'operation_foo',
        path_template => '/foo/{foo_id}',
        path_captures => { foo_id => 'hi' },
      },
      result => { valid => true },
    });
};

done_testing;
