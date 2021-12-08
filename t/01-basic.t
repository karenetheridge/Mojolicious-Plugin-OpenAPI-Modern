# vim: set ts=8 sts=2 sw=2 tw=100 et :
use strict;
use warnings;
use 5.016;

use if "$]" >= 5.022, experimental => 're_strict';
no if "$]" >= 5.031009, feature => 'indirect';
no if "$]" >= 5.033001, feature => 'multidimensional';
no if "$]" >= 5.033006, feature => 'bareword_filehandles';
use open ':std', ':encoding(UTF-8)'; # force stdin, stdout, stderr into utf8

use Test::More 0.88;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Mojolicious::Plugin::OpenAPI::Modern;

fail('this test is TODO!');
done_testing;
