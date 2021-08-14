#!perl

use warnings;
use strict;

use JSON qw(from_json);
use NIOS;
use Test::Fatal;
use Test::More;

use lib 't/tlib';
use Test::SpawnNIOS;

my $nios = Test::SpawnNIOS->nios();
END { $nios->shitdown() if $nios }

like(
    exception { my $n = NIOS->new() },
    qr/\w+ is required!/,
    'Missing required connection parameters',
);

like(
    exception {
        my $n = NIOS->new(
            username  => "x",
            password  => "x",
            wapi_addr => "x",
            scheme    => "x"
        )
    },
    qr/^scheme not supported/,
    'Not supported scheme',
);

my $n = NIOS->new(
    username  => "username",
    password  => "password",
    wapi_addr => $nios->addr,
    scheme    => "http"
);

is(
    exception { $n->do_something_undefined() },
    undef, "Undefined method called",
);

my $x = $n->get_a_record();
ok( $x->{_rc} == 400 );
ok( !$x->is_success );
ok( from_json( $x->decoded_content )->{code} eq "Client.Ibap.Proto" );

$x = $n->get_a_record( params => { _paging => 1 } );
ok( $x->{_rc} == 400 );
ok( !$x->is_success );
ok( from_json( $x->decoded_content )->{code} eq "Client.Ibap.Proto" );
ok( from_json( $x->decoded_content )->{text} eq
      "_return_as_object needs to be enabled for paging requests." );

$x = $n->get_a_record(
    params => {
        _paging           => 1,
        _max_results      => 1,
        _return_as_object => 1
    }
);
ok( $x->{_rc} == 200 );
ok( $x->is_success );

foreach ( @{ from_json( $x->decoded_content )->{result} } ) {
    my $x = $n->delete( ref => $_->{_ref} );
}

$x = $n->create_a_record(
    name     => "rhds.ext.home",
    ipv4addr => "10.0.0.1",
    extattrs => {
        "Tenant ID"       => { value => "home" },
        "CMP Type"        => { value => "OpenStack" },
        "Cloud API Owned" => { value => "True" }
    }
);
ok( $x->{_rc} == 201 );

my $ref = substr( $x->{_content}, 1, -1 );

$x = $n->get_a_record(
    params => {
        _paging           => 1,
        _max_results      => 1,
        _return_as_object => 1
    }
);
ok( $ref eq from_json( $x->decoded_content )->{result}[0]->{_ref} );

$x = $n->update(
    ref  => $ref,
    name => "rhds-1.ext.home"
);
ok( $x->{_rc} == 200 );
$x = $n->get_a_record(
    params => {
        _paging           => 1,
        _max_results      => 1,
        _return_as_object => 1
    }
);
ok( "rhds-1.ext.home" eq from_json( $x->decoded_content )->{result}[0]->{name}
);

## All done
done_testing();
