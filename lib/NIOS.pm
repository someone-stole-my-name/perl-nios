package NIOS;

# ABSTRACT: Perl binding for NIOS
# VERSION
# AUTHORITY

use warnings;
use strict;

use Carp qw(croak);
use JSON qw(to_json);
use LWP::UserAgent;
use MIME::Base64 qw(encode_base64);
use URI;
use URI::QueryParam;

sub new {
  my ( $class, %args ) = @_;
  my $self = bless {}, $class;

  $self->{debug} = $args{debug} || $ENV{NIOS_DEBUG};
  $self->{debug} = 0 if !defined $self->{'debug'};

  defined $args{$_}
    and $self->{$_} = $args{$_}
    for qw(wapi_version username password scheme insecure timeout wapi_addr);

  $self->{wapi_version} = 'v2.7'  if !defined $self->{'wapi_version'};
  $self->{scheme}       = 'https' if !defined $self->{'scheme'};
  $self->{insecure}     = 0       if !defined $self->{'insecure'};
  $self->{timeout}      = 10      if !defined $self->{'timeout'};

  defined( $self->{$_} )
    or croak("$_ is required!")
    for qw(username password wapi_addr);

  ( ( $self->{scheme} eq "http" ) or ( $self->{scheme} eq "https" ) )
    or croak( "scheme not supported: " . $self->{scheme} );

  $self->{ua} = LWP::UserAgent->new( timeout => $self->{timeout} );
  $self->{ua}->agent( 'NIOS-perl/' . $NIOS::VERSION );
  $self->{ua}->ssl_opts( verify_hostname => 0, SSL_verify_mode => 0x00 )
    if $self->{insecure} and $self->{scheme} eq "https";
  $self->{ua}->default_header( "Accept"       => "application/json" );
  $self->{ua}->default_header( "Content-Type" => "application/json" );
  $self->{ua}->default_header( "Authorization" => "Basic "
      . encode_base64( $self->{username} . ":" . $self->{password} ) );

  $self->{base_url} =
      $self->{scheme} . "://"
    . $self->{'wapi_addr'}
    . "/wapi/"
    . $self->{'wapi_version'} . "/";

  return $self;
}

sub DESTROY { }

our $AUTOLOAD;

sub AUTOLOAD {
  my $command = $AUTOLOAD;

  $command =~ s/.*://;

  my $method = sub { shift->__do_cmd( $command, @_ ) };

  goto $method;
}

sub __do_cmd {
  my ( $self, $command, %args ) = @_;

  my %hash;
  @hash{ "action", "resource", "type" } =
    $command =~ /^([a-z]+)_?([a-z]+)?_?([a-z]+)?$/;

  return $self->__std_cmd( "PUT", %args )
    if ( $hash{action} and $hash{action} eq "update" )
    and ( !$hash{resource} and !$hash{type} );

  return $self->__std_cmd( "DELETE", %args )
    if ( $hash{action} and $hash{action} eq "delete" )
    and ( !$hash{resource} and !$hash{type} );

  $args{ref} = join( ":", $hash{type}, $hash{resource} )
    and return $self->__std_cmd( "GET", %args )
    if ( $hash{action} and $hash{action} eq "get" )
    and ( $hash{resource} and $hash{type} );

  $args{ref} = join( ":", $hash{type}, $hash{resource} )
    and return $self->__std_cmd( "POST", %args )
    if ( $hash{action} and $hash{action} eq "create" )
    and ( $hash{resource} and $hash{type} );
}

sub __std_cmd {
  my ( $self, $op, %args ) = @_;

  my $ref          = delete $args{ref} or croak("ref is required!");
  my $params       = delete $args{params};
  my $query_params = "";

  if ( defined $params ) {
    my $u = URI->new( "", "http" );
    $query_params = "?";
    foreach ( keys %{$params} ) {
      $u->query_param( $_ => $params->{$_} );
    }
    $query_params .= $u->query;
  }

  my $request =
    HTTP::Request->new( $op, $self->{base_url} . $ref . $query_params );

  if ( $op eq "PUT" or $op eq "POST" ) {
    $request->content( to_json( \%args ) );
  }

  return $self->{ua}->request($request);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

NIOS - Perl binding for NIOS

=head1 SYNOPSIS
 
    # Read below for a list of options
    my $n = NIOS->new(
        username  => "username",
        password  => "password",
        wapi_addr => "10.0.0.1",
    );


    $x = $n->get_a_record(
        params => {
            _paging           => 1,
            _max_results      => 1,
            _return_as_object => 1
        }
    );
    say from_json( $x->decoded_content )->{result}[0]->{_ref};

=head1 DESCRIPTION

Perl bindings for L<https://www.infoblox.com/company/why-infoblox/nios-platform/>

=head1 CONSTRUCTOR
 
=head2 new

    my $n = NIOS->new(
        username  => "username",
        password  => "password",
        wapi_addr => "10.0.0.1",
    );

=head3 C<< insecure >>

Enable or disable verifying SSL certificates when C<< scheme >> is C<< https >>.

B<Default>: false

=head3 C<< password >>

Specifies the password to use to authenticate the connection to the remote instance of NIOS.

=head3 C<< scheme >>

B<Default>: https

=head3 C<< timeout >>

The amount of time before to wait before receiving a response.

B<Default>: 10

=head3 C<< username >>

Configures the username to use to authenticate the connection to the remote instance of NIOS.

=head3 C<< wapi_addr >>

DNS hostname or address for connecting to the remote instance of NIOS WAPI.

=head3 C<< wapi_version >>

Specifies the version of WAPI to use.

B<Default>: v2.7

=head1 Methods

Methods return an L<HTTP::Response> object.

=head3 C<< create >>

    # Create anew 'a' resources of type 'record':
    $x = $n->create_a_record(
        name     => "rhds.ext.home",
        ipv4addr => "10.0.0.1",
        extattrs => {
            "Tenant ID"       => { value => "home" },
            "CMP Type"        => { value => "OpenStack" },
            "Cloud API Owned" => { value => "True" }
        }
    );

=head3 C<< delete >>

    # Delete a WAPI Object Reference
    $x = $n->delete(ref => $object_ref);

=head3 C<< get >>

    # List all 'a' resources of type 'record' with:
    #   pagination
    #   limiting results to 1
    #   returning response as an object
    $x = $n->get_a_record(
        params => {
            _paging           => 1,
            _max_results      => 1,
            _return_as_object => 1
        }
    );

=head3 C<< update >>

    # Update a WAPI Object Reference
    $x = $n->update(
        ref => $object_ref,
        name => "updated_name"
    );

=cut
