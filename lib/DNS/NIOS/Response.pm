## no critic
package DNS::NIOS::Response;

# ABSTRACT: WAPI Response object
# VERSION
# AUTHORITY

## use critic
use strictures 2;
use Carp qw(croak);
use JSON qw(from_json to_json);
use Try::Tiny;
use namespace::clean;
use Class::Tiny qw( _http_response );

=pod

=for Pod::Coverage BUILD

=cut

sub BUILD {
  my $self = shift;
  croak "Missing required attribute" unless defined $self->_http_response;
  croak "Bad attribute" unless ref $self->_http_response eq "HTTP::Response";
}

=pod

=method code

Response code

=cut

sub code {
  return shift->_http_response->{_rc};
}

=pod

=method is_success

Wether the request was successful

=cut

sub is_success {
  return shift->_http_response->is_success;
}

=pod

=method content

Response content as hashref. If the content for some reason cannot be converted,
it will return the decoded_content as is.

=cut

sub content {
  my $self = shift;
  my $h;
  try {
    $h = from_json( $self->_http_response->decoded_content );

  }
  catch {
    $h = $self->_http_response->decoded_content;

    # For some reason <5.28 returns a quoted string during test
    $h =~ s/^"|"$//g;
  };
  return $h;
}

=pod

=method json

Return a json string.

=cut

sub json {
  my $self = shift;
  try {
    my $h = to_json( $self->content, @_ );
    return $h;
  };
  return to_json( { content => $self->content }, @_ );
}

=pod

=method pretty

Return a prettified json string.

=cut

sub pretty {
  return shift->json( { utf8 => 1, pretty => 1 } );
}

1;
