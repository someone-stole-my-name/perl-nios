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

my $n = NIOS->new(
    username  => "username",
    password  => "password",
    wapi_addr => $nios->addr,
    scheme    => "http"
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
ok( from_json( $x->decoded_content )->{next_page_id} );
my $next_page_id = from_json( $x->decoded_content )->{next_page_id};
ok( from_json( $x->decoded_content )->{result} );
ok( from_json( $x->decoded_content )->{result}[0]->{_ref} );
my $ref = from_json( $x->decoded_content )->{result}[0]->{_ref};

$x = $n->get_a_record(
    params => {
        _paging           => 1,
        _max_results      => 1,
        _return_as_object => 1,
        _page_id          => $next_page_id
    }
);
ok( $x->{_rc} == 200 );
ok( $x->is_success );
ok( from_json( $x->decoded_content )->{next_page_id} );
ok( from_json( $x->decoded_content )->{next_page_id} ne $next_page_id );
ok( from_json( $x->decoded_content )->{result} );
ok( from_json( $x->decoded_content )->{result}[0]->{_ref} );
ok( from_json( $x->decoded_content )->{result}[0]->{_ref} ne $ref );

$x = $n->create_a_record( fail => 1 );
ok( $x->{_rc} != 201 );

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
ok( substr( $x->{_content}, 1, -1 ) eq $ref );

$x = $n->update(
    ref  => $ref,
    name => "rhds.ext.home"
);
ok( $x->{_rc} == 200 );

## All done
done_testing();
