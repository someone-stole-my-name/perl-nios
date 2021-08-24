## no critic
package DNS::NIOS::Traits::AutoPager;

# ABSTRACT: Handle pagination automagically
# VERSION
# AUTHORITY

## use critic
use strictures 2;
use namespace::clean;
use Role::Tiny;
use Data::Dumper;

requires qw( get );

around 'get' => sub {
  my ( $orig, $self, %args ) = @_;

  my %params = (
    _return_as_object => 1,
    _max_results      => 100,
    _paging           => 1
  );

  my @responses;
  my $max_results = $args{params}->{_max_results} // 0;

  $args{params}
    ? %{ $args{params} } =
    ( %{ $args{params} }, %params )
    : $args{params} = \%params;

  my $response = $orig->( $self, %args );
  return [$response] if !$response->is_success;

  push( @responses, $response );
  while ( $response->content->{next_page_id} ) {
    if ($max_results) {
      last if $#responses >= $max_results - 1;
    }
    %{ $args{params} } =
      ( %{ $args{params} }, _page_id => $response->content->{next_page_id} );
    $response = $orig->( $self, %args );
    push( @responses, $response );
  }

  return \@responses;
};

1;

__END__

=pod

=head1 DESCRIPTION

This role replaces the get method to handle pagination automatically, it turns
the result of all get operations into an ArrayRef of DNS::NIOS::Response.
When _max_results is present in the request, it is honored to some extent.

=cut
