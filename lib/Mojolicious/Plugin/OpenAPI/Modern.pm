use strict;
use warnings;
package Mojolicious::Plugin::OpenAPI::Modern;
# vim: set ts=8 sts=2 sw=2 tw=100 et :
# ABSTRACT: ...
# KEYWORDS: ...

our $VERSION = '0.001';

use 5.016;
use if "$]" >= 5.022, experimental => 're_strict';
no if "$]" >= 5.031009, feature => 'indirect';
no if "$]" >= 5.033001, feature => 'multidimensional';
no if "$]" >= 5.033006, feature => 'bareword_filehandles';

1;
__END__

=pod

=head1 SYNOPSIS

  use Mojolicious::Plugin::OpenAPI::Modern;

  ...

=head1 DESCRIPTION

...

=head1 FUNCTIONS/METHODS

=head2 foo

...

=head1 ACKNOWLEDGEMENTS

...

=head1 SEE ALSO

=for :list
* L<foo>

=head1 SUPPORT

You can also find me on the L<JSON Schema Slack server|https://json-schema.slack.com> and L<OpenAPI Slack
server|https://open-api.slack.com>, which are also great resources for finding help.

=cut
