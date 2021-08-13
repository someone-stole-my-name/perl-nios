#!/usr/bin/perl
use Mojolicious::Lite;
use Mojo::Parameters;
use Test::Deep::NoTest qw(eq_deeply);
use JSON qw(from_json);

sub request_has_params {
    my $h = shift->req->params->to_hash;

    if ( %{$h} ) {
        foreach ( keys %{$h} ) {
            return 0 if $h->{$_} eq '';
        }
        return 1;
    }
    else {
        return 0;
    }
    return 0;
}

sub params_match_template {
    my $c = shift;

    my $available_templates = $c->app->static->{index};

    foreach ( keys %{$available_templates} ) {
        if ( $_ =~ /^.+?\/(.+)\?.+\.json\.ep$/m ) {
            if ( $1 eq $c->stash('p') ) {
                if ( $_ =~ /\?(.+)\.json\.ep$/m ) {
                    my $template_params = Mojo::Parameters->new($1);
                    if (
                        eq_deeply(
                            $template_params->to_hash,
                            $c->req->params->to_hash
                        )
                      )
                    {
                        return substr( $_, 0, -8 );
                    }

                }
            }
        }

    }

    return 0;
}

app->log->level('error');

plugin 'basic_auth';

any '/*p' => sub {
    my ($c) = @_;

    my $template_name   = "ANY/404";
    my $template_format = "json";

    if ( !request_has_params($c) and uc $c->req->method eq "GET" ) {
        $template_name = join( '/', uc $c->req->method, $c->stash('p') );
    }
    elsif ( request_has_params($c) and params_match_template($c) ) {
        $template_name = params_match_template($c);
    }
    elsif ( !request_has_params($c)
        and ( uc $c->req->method eq "POST" or uc $c->req->method eq "PUT" ) )
    {
        $template_format = "txt";
        $template_name   = join( '/', uc $c->req->method, $c->stash('p') );

        my $required_payload = from_json(
            $c->render_to_string(
                template => "PAYLOAD/$template_name",
                format   => 'json'
            )->to_string
        );

        $c->render( text => 'bad payload', status => 500 ) and return
          unless eq_deeply( $c->req->json, $required_payload );
    }

    my $template = $c->render_to_string(
        template => $template_name,
        format   => $template_format
    );

    chomp($template);
    chomp( my $json = substr( $template, 0, -3 ) );
    chomp( my $status_code = substr( $template, -3 ) );

    return $c->render(
        data   => $json,
        status => $status_code,
      )
      if $c->basic_auth(
        realm => sub { return 1 if "@_" eq 'username password' } );
};
app->start;

__DATA__

@@ ANY/404.json.ep
{
    "code": "404",
    "text": "Template with parameters not found."
}404

@@ GET/wapi/v2.7/record:a?_paging=1.json.ep
{
    "Error": "AdmConProtoError: _return_as_object needs to be enabled for paging requests.",
    "code": "Client.Ibap.Proto",
    "text": "_return_as_object needs to be enabled for paging requests."
}400


@@ GET/wapi/v2.7/record:a.json.ep
{
    "Error": "AdmConProtoError: Result set too large (> 1000)",
    "code": "Client.Ibap.Proto",
    "text": "Result set too large (> 1000)"
}400

@@ POST/wapi/v2.7/record:a.txt.ep
"record:a/ZG5zLmJpbmRfY:rhds.ext.home/default"
201

@@ PAYLOAD/POST/wapi/v2.7/record:a.json.ep
{
	"name":"rhds.ext.home",
	"ipv4addr":"10.0.0.1",
    "extattrs": {
        "Tenant ID": { "value": "home" },
        "CMP Type": { "value": "OpenStack" },
        "Cloud API Owned": { "value": "True" }
    }
}

@@ PUT/wapi/v2.7/record:a/ZG5zLmJpbmRfY:rhds.ext.home/default.txt.ep
"record:a/ZG5zLmJpbmRfY:rhds.ext.home/default"
200

@@ PAYLOAD/PUT/wapi/v2.7/record:a/ZG5zLmJpbmRfY:rhds.ext.home/default.json.ep
{
	"name":"rhds.ext.home"
}

@@ GET/wapi/v2.7/record:a?_paging=1&_max_results=1&_return_as_object=1.json.ep
{
    "next_page_id": "789c55904d6ec3201046f",
    "result": [
        {
            "_ref": "record:a/ZG5zLmJpbmRfY:rhds.ext.home/default",
            "ipv4addr": "10.0.0.1",
            "name": "rhds.ext.home",
            "view": "default"
        }
    ]
}200

@@ GET/wapi/v2.7/record:a?_paging=1&_max_results=1&_return_as_object=1&_page_id=789c55904d6ec3201046f.json.ep
{
    "next_page_id": "789c55904b6ec3300c44f",
    "result": [
        {
            "_ref": "record:a/ZG5zLmJpbmRfYSQ:rhds-1.ext.home/default",
            "ipv4addr": "10.0.0.2",
            "name": "rhds-1.ext.home",
            "view": "default"
        }
    ]
}200
