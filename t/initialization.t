# vim: set ts=8 sts=2 sw=2 tw=100 et :
use strictures 2;
use utf8;
use 5.020;
use Test::More 0.88;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use stable 0.031 'postderef';
use experimental 'signatures';
use if "$]" >= 5.022, experimental => 're_strict';
no if "$]" >= 5.031009, feature => 'indirect';
no if "$]" >= 5.033001, feature => 'multidimensional';
no if "$]" >= 5.033006, feature => 'bareword_filehandles';
no if "$]" >= 5.041009, feature => 'smartmatch';
no feature 'switch';
use open ':std', ':encoding(UTF-8)'; # force stdin, stdout, stderr into utf8
use Mojolicious::Plugin::OpenAPI::Modern;
use Path::Tiny;
use Test::Mojo;

use lib 't/lib';

subtest 'raw schema' => sub {
  my $t = Test::Mojo->new(
    'BasicApp',
    {
      openapi => {
        schema => {
          openapi => '3.1.0',
          info => {
            title => 'Test API with raw schema',
            version => '1.2.3',
          },
          paths => {},
        },
      },
    },
  );

  is($t->app->openapi->document_get('/info/title'), 'Test API with raw schema',
    'access schema through OM object');
};

subtest 'YAML schema' => sub {
  my $filename = Path::Tiny->tempfile;
  $filename->move($filename.'.yaml');
  $filename = path($filename.'.yaml');
  $filename->spew_raw(<<'YAML');
openapi: 3.1.0
info:
  title: Test API with yaml document
  version: 1.2.3
paths: {}
YAML

  my $t = Test::Mojo->new(
    'BasicApp',
    { openapi => { document_filename => $filename } },
  );

  is($t->app->openapi->document_get('/info/title'), 'Test API with yaml document',
    'access schema through OM object');
};

subtest 'JSON schema' => sub {
  my $filename = Path::Tiny->tempfile;
  $filename->move($filename.'.json');
  $filename = path($filename.'.json');
  $filename->spew_raw(<<'JSON');
{
  "openapi": "3.1.0",
  "info": {
    "title": "Test API with json document",
    "version": "1.2.3"
  },
  "paths": {}
}
JSON

  my $t = Test::Mojo->new(
    'BasicApp',
    { openapi => { document_filename => $filename } },
  );

  is($t->app->openapi->document_get('/info/title'), 'Test API with json document',
    'access schema through OM object');
};

subtest 'override with our own object' => sub {
  my $openapi = OpenAPI::Modern->new(
    openapi_uri    => '',
    openapi_schema => {
      openapi => '3.1.0',
      info => {
        title => 'Test API with our own object',
        version => '1.2.3',
      },
      paths => {},
    },
  );

  my $t = Test::Mojo->new(
    'BasicApp',
    { openapi => { openapi_obj => $openapi } },
  );

  is($t->app->openapi->document_get('/info/title'), 'Test API with our own object',
    'plugin uses a pre-constructed OpenAPI::Modern object');
};

done_testing;
