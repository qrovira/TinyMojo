use Mojo::Base -strict;

use Cwd 'abs_path';
use File::Basename 'dirname';
use File::Spec::Functions 'catfile';

use Test::More;
use Test::Mojo;

BEGIN {
    $ENV{MOJO_CONFIG} = abs_path catfile(dirname(__FILE__), 'tokens.conf');
}

my $t = Test::Mojo->new('TinyMojo');
my $c = $t->app->build_controller;

my %seen;
my %seen_ids;
for(1..10000) {
    my $id; $id = int(rand(100_000))
        while( !defined($id) || $seen_ids{$id}++ );
    my $token = $c->id_to_token( $id );
    ok $token, "Generated a token";
    ok !$seen{$token}, "No token clash";
    is $c->token_to_id( $token ), $id, "Obtained same id back"
        or diag "Failed token was $token";
    $seen{$token} = 1;
}


done_testing();
