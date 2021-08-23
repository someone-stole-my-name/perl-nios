#!perl

use strictures 2;

use JSON qw(from_json);
use DNS::NIOS;
use Test::Fatal;
use Test::More;

use lib 't/tlib';
use Test::SpawnNIOS;

my $nios = Test::SpawnNIOS->nios();
END { $nios->shitdown() if $nios }

my $n = DNS::NIOS->new(
  username  => "username",
  password  => "password",
  wapi_addr => $nios->addr,
  scheme    => "http"
);

my $x = $n->create_a_record(
  payload => {
    name     => "rhds.ext.home",
    ipv4addr => "10.0.0.1",
    extattrs => {
      "Tenant ID"       => { value => "home" },
      "CMP Type"        => { value => "OpenStack" },
      "Cloud API Owned" => { value => "True" }
    }
  }
);
ok( $x->code == 201 );

done_testing();
