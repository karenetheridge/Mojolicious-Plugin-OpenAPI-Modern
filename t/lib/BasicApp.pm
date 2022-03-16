package BasicApp;
use Mojo::Base 'Mojolicious', -signatures;

sub startup ($self) {
  $self->plugin('OpenAPI::Modern', $self->config->{openapi});

  my $routes = $self->routes;
  $routes->any('/foo*catchall' => sub ($c) {
    my $result = $c->validate_request;
    $c->render(
      status => ($result ? 200 : 400),
      json => {
        stash => $c->stash('openapi'),
        result => $result,
      },
    );
  });
}

1;
