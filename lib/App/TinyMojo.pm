package App::TinyMojo;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Router
  my $r = $self->routes;

  # Configuration
  $self->plugin('config');

  # Database
  $self->plugin( database => { databases => { db => $self->config->{database} } } );

  # Translations
  $self->plugin('wolowitz');
  $self->defaults( language => $self->config->{language} );

  # Session secret token
  $self->secrets( $self->config->{secrets} );

  # Normal route to controller
  $r->get('/')->to('main#index');

  # Actions
  $r->post('/do/shorten')->to('main#shorten');

  # Handle short url
  $r->get('/:shorturl')->to('main#redirect');
}

1;
