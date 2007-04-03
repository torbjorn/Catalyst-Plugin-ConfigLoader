package MockApp;

use Test::More tests => 7;

use Cwd;
$ENV{ CATALYST_HOME } = cwd . '/t/mockapp';

use_ok( 'Catalyst', qw( ConfigLoader ) );

__PACKAGE__->setup;

use Data::Dumper; print Dumper __PACKAGE__->config;

ok( __PACKAGE__->config );
is( __PACKAGE__->config->{ 'Controller::Foo' }->{ foo }, 'bar' );
is( __PACKAGE__->config->{ 'Controller::Foo' }->{ new }, 'key' );
is( __PACKAGE__->config->{ 'Model::Baz' }->{ qux }, 'xyzzy' );
is( __PACKAGE__->config->{ 'Model::Baz' }->{ another }, 'new key' );
is( __PACKAGE__->config->{ 'view' }, 'View::TT::New' );
