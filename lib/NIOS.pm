## no critic
package NIOS;

# ABSTRACT: Perl binding for NIOS
# VERSION
# AUTHORITY

## use critic
use warnings;
use strict;

use Carp qw(croak);
use JSON qw(to_json);
use LWP::UserAgent;
use MIME::Base64 qw(encode_base64);
use URI;
use URI::QueryParam;

use constant TIMEOUT => 10; ## no critic (ValuesAndExpressions::ProhibitConstantPragma)

sub new {
  my ( $class, %args ) = @_;
  my $self = bless {}, $class;

  $self->{debug} = $args{debug} || $ENV{NIOS_DEBUG};
  $self->{debug} = 0
    if !defined $self->{'debug'}; ## no critic (ControlStructures::ProhibitPostfixControls)

  defined $args{$_}
    and $self->{$_} = $args{$_}
    for qw(wapi_version username password scheme insecure timeout wapi_addr); ## no critic (ControlStructures::ProhibitPostfixControls)

  $self->{wapi_version} = 'v2.7'
    if !defined $self->{'wapi_version'};                                      ## no critic (ControlStructures::ProhibitPostfixControls)
  $self->{scheme} = 'https'
    if !defined $self->{'scheme'};                                            ## no critic (ControlStructures::ProhibitPostfixControls)
  $self->{insecure} = 0
    if !defined $self->{'insecure'};                                          ## no critic (ControlStructures::ProhibitPostfixControls)
  $self->{timeout} = TIMEOUT
    if !defined $self->{'timeout'};                                           ## no critic (ControlStructures::ProhibitPostfixControls)

  defined( $self->{$_} )
    or croak("$_ is required!")
    for qw(username password wapi_addr);                                      ## no critic (ControlStructures::ProhibitPostfixControls)

  ( ( $self->{scheme} eq 'http' ) or ( $self->{scheme} eq 'https' ) )
    or croak("scheme not supported: $self->{scheme}");

  $self->{ua} = LWP::UserAgent->new( timeout => $self->{timeout} );
  $self->{ua}->agent( 'NIOS-perl/' . $NIOS::VERSION );
  $self->{ua}->ssl_opts( verify_hostname => 0, SSL_verify_mode => 0x00 )
    if $self->{insecure} and $self->{scheme} eq 'https';                      ## no critic (ControlStructures::ProhibitPostfixControls)
  $self->{ua}->default_header( 'Accept'       => 'application/json' );
  $self->{ua}->default_header( 'Content-Type' => 'application/json' );
  $self->{ua}->default_header( 'Authorization' => 'Basic '
      . encode_base64("$self->{username}:$self->{password}") );

  $self->{base_url} =
    "$self->{scheme}://$self->{'wapi_addr'}/wapi/$self->{'wapi_version'}/";

  return $self;
}

sub DESTROY { }

our $AUTOLOAD;

sub AUTOLOAD { ## no critic (ClassHierarchies::ProhibitAutoloading)
  ( my $command = $AUTOLOAD ) =~ s/.*://xms;

  my $method = sub { shift->__do_cmd( $command, @_ ) };

  # Speed up future calls
  no strict 'refs';     ## no critic (TestingAndDebugging::ProhibitNoStrict)
  *$AUTOLOAD = $method; ## no critic (References::ProhibitDoubleSigils)

  goto $method;
}

sub __do_cmd {
  my ( $self, $command, %args ) = @_;

  my %hash;
  @hash{ 'action', 'resource', 'type' } =
    $command =~ /^([[:lower:]]+)_?([[:lower:]]+)?_?([[:lower:]]+)?$/xms;

  $args{ref} = join q{:}, $hash{type}, $hash{resource} unless $args{ref};

  return $self->__std_cmd( 'PUT', %args )
    if ( $hash{action} and $hash{action} eq 'update' )
    and ( not $hash{resource} and not $hash{type} );

  return $self->__std_cmd( 'DELETE', %args )
    if ( $hash{action} and $hash{action} eq 'delete' )
    and ( not $hash{resource} and not $hash{type} );

  return $self->__std_cmd( 'GET', %args )
    if ( $hash{action} and $hash{action} eq 'get' ) ## no critic (ControlStructures::ProhibitPostfixControls)
    and ( $hash{resource} and $hash{type} );

  return $self->__std_cmd( 'POST', %args )
    if ( $hash{action} and $hash{action} eq 'create' ) ## no critic (ControlStructures::ProhibitPostfixControls)
    and ( $hash{resource} and $hash{type} );

  return;
}

sub __std_cmd {
  my ( $self, $op, %args ) = @_;

  my $ref          = delete $args{ref} or croak('ref is required!');
  my $params       = delete $args{params};
  my $query_params = q{};

  if ( defined $params ) {
    my $u = URI->new( q{}, 'http' );
    $query_params = q{?};
    foreach ( keys %{$params} ) {
      $u->query_param( $_ => $params->{$_} );
    }
    $query_params .= $u->query;
  }

  my $request =
    HTTP::Request->new( $op, $self->{base_url} . $ref . $query_params );

  if ( $op eq 'PUT' or $op eq 'POST' ) {
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

=for html <a href="https://www.travis-ci.com/someone-stole-my-name/perl-nios"><img src="https://www.travis-ci.com/someone-stole-my-name/perl-nios.svg?branch=master"></a>

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
