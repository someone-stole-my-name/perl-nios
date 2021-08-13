#!/usr/bin/env perl
use JSON qw(from_json);
use Mojolicious::Lite;
use Data::GUID qw( guid_string );

my $creds     = { username => "username", password => "password" };
my @records_a = ();

app->log->level('error');

plugin 'basic_auth';

del '/wapi/v2.7/record:a/*ref' => sub {
    my ($c) = @_;
    return $c->render( text => "Forbidden", status => 401 )
      unless $c->basic_auth(
        realm => sub {
            return 1
              if "@_" eq join( " ", $creds->{username}, $creds->{password} );
        }
      );

    my $record_exists    = 0;
    my $record_exists_at = 0;
    foreach (@records_a) {
        print STDERR ("\n\nComparing: " . $_->{_ref} . " and " . "record:a/" . $c->stash('ref')) . "\n\n";
        if ( $_->{_ref} eq "record:a/" . $c->stash('ref') ) {
            $record_exists = 1;
            last;
        }
        $record_exists_at++;
    }

    return $c->render( text => "Not found", status => 404 ) if !$record_exists;
    splice( @records_a, $record_exists_at, 1 );
    return $c->render( text => "deleted", status => 200 );
};

put '/wapi/v2.7/record:a/*ref' => sub {
    my ($c) = @_;
    return $c->render( text => "Forbidden", status => 401 )
      unless $c->basic_auth(
        realm => sub {
            return 1
              if "@_" eq join( " ", $creds->{username}, $creds->{password} );
        }
      );

    my $record_exists    = 0;
    my $record_exists_at = 0;
    foreach (@records_a) {
        if ( $_->{_ref} eq "record:a/" . $c->stash('ref') ) {
            $record_exists = 1;
            last;
        }
        $record_exists_at++;
    }

    return $c->render( text => "Not found", status => 404 ) if !$record_exists;

    foreach ( keys %{ $c->req->json } ) {
        $records_a[$record_exists_at]->{$_} = $c->req->json->{$_};
    }

    return $c->render(
        text   => "\"" . $records_a[$record_exists_at]->{_ref} . "\"",
        status => 200
    );
};

post '/wapi/v2.7/record:a' => sub {
    my ($c) = @_;
    return $c->render( text => "Forbidden", status => 401 )
      unless $c->basic_auth(
        realm => sub {
            return 1
              if "@_" eq join( " ", $creds->{username}, $creds->{password} );
        }
      );

    defined $c->req->json->{$_}
      or return $c->render( text => "Bad Payload", status => 400 )
      for qw(name ipv4addr);

    foreach (@records_a) {
        return $c->render( text => "Conflict", status => 409 )
          if $_->{name} eq $c->req->json->{name};
    }

    $c->req->json->{_ref} =
      "record:a/" . lc guid_string() . ":" . $c->req->json->{name} . "/default";

    $c->req->json->{view} = "default";
    push( @records_a, $c->req->json );

    $c->render( text => "\"" . $c->req->json->{_ref} . "\"", status => 201 );
};

get '/wapi/v2.7/record:a' => sub {
    my ($c) = @_;
    return $c->render( text => "Forbidden", status => 401 )
      unless $c->basic_auth(
        realm => sub {
            return 1
              if "@_" eq join( " ", $creds->{username}, $creds->{password} );
        }
      );

    if ( !%{ $c->req->params->to_hash } ) {
        return $c->render(
            json => {
                Error => "AdmConProtoError: Result set too large (> 1000)",
                code  => "Client.Ibap.Proto",
                text  => "Result set too large (> 1000)"
            },
            status => 400
        );
    }
    elsif ( %{ $c->req->params->to_hash }{_paging}
        and !defined %{ $c->req->params->to_hash }{_return_as_object} )
    {
        return $c->render(
            json => {
                Error =>
"AdmConProtoError: _return_as_object needs to be enabled for paging requests.",
                code => "Client.Ibap.Proto",
                text =>
                  "_return_as_object needs to be enabled for paging requests."
            },
            status => 400
        );
    }
    elsif ( %{ $c->req->params->to_hash }{_paging}
        and %{ $c->req->params->to_hash }{_return_as_object} )
    {
        return $c->render(
            json => {
                next_page_id => "789c55904d6ec3201046f",
                result       => \@records_a
            },
            status => 200
        );
    }
};

app->start;
