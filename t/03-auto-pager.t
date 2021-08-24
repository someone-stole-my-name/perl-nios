#!perl

use strictures 2;

use JSON qw(from_json);
use DNS::NIOS;
use Test::Fatal;
use Test::More;

use lib 't/tlib';
use Test::SpawnNIOS;
use Data::Dumper;

my $nios = Test::SpawnNIOS->nios();
END { $nios->shitdown() if $nios }

my $n = DNS::NIOS->new(
  username  => "username",
  password  => "password",
  wapi_addr => $nios->addr,
  scheme    => "http",
  traits    => [ 'DNS::NIOS::Traits::ApiMethods', 'DNS::NIOS::Traits::AutoPager' ]
);

my $x = $n->list_a_records();
ok( ref($x) eq 'ARRAY' );
ok( ref( @{$x}[0] ) eq 'DNS::NIOS::Response' );
my $response_length = scalar( @{$x} );

$x = $n->list_a_records( params => { _max_results => 200 } );
ok( ref($x) eq 'ARRAY' );
print STDERR Dumper( scalar( @{$x} ) );
ok( scalar( @{$x} ) != $response_length );
ok( scalar( @{$x} ) == 200 );

done_testing();
