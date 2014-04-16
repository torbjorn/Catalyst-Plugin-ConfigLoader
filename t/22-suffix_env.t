use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;

BEGIN {
    eval { require Catalyst; Catalyst->VERSION( '5.80001' ); };

    plan skip_all => 'Catalyst 5.80001 required' if $@;
    plan tests => 5;

    $ENV{ TESTAPP_CONFIG_LOCAL_SUFFIX } = 'test';
    use_ok 'Catalyst::Test', 'TestApp';
}

ok my ( $res, $c ) = ctx_request( '/' ), 'context object';
is( get( '/appconfig/foo' ), "bar", "conf foo from testapp_test set" );
is( get( '/appconfig/baz' ), "test", "conf baz from testapp_test set" );
is( get( '/appconfig/unknown' ), "", "unknown var not matched" );
