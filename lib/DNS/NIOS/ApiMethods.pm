## no critic
package DNS::NIOS::ApiMethods;

# ABSTRACT: Convenient sugar for NIOS
# VERSION
# AUTHORITY

## use critic
use strictures 2;
use namespace::clean;
use Role::Tiny;

requires qw(create update get delete);

=method create_a_record

=cut

sub create_a_record {
  shift->create( path => 'record:a', @_ );
}

=method create_cname_record

=cut

sub create_cname_record {
  shift->create( path => 'record:cname', @_ );
}

=method create_host_record

=cut

sub create_host_record {
  shift->create( path => 'record:host', @_ );
}

=method list_a_records

=cut

sub list_a_records {
  shift->get( path => 'record:a', @_ );
}

=method list_aaaa_records

=cut

sub list_aaaa_records {
  shift->get( path => 'record:aaaa', @_ );
}

=method list_cname_records

=cut

sub list_cname_records {
  shift->get( path => 'record:cname', @_ );
}

=method list_host_records

=cut

sub list_host_records {
  shift->get( path => 'record:host', @_ );
}

=method list_ptr_records

=cut

sub list_ptr_records {
  shift->get( path => 'record:ptr', @_ );
}

=method list_txt_records

=cut

sub list_txt_records {
  shift->get( path => 'record:txt', @_ );
}

1;

__END__

=pod

=head1 DESCRIPTION

This role provides convenient methods for calling API endpoints.

Theese methods are simply sugar around the basic c<create> and c<get> methods. For example, these two calls are equivalent:

    $n->list_a_records();
    $n->get( path => 'record:a');


=cut
