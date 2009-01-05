package TestApp;

use strict;
use warnings;

use MRO::Compat;

use Catalyst qw/ConfigLoader/;

our $VERSION = '0.01';

__PACKAGE__->setup;

sub finalize_config {
    my $c = shift;
    $c->config( foo => 'bar' );
    $c->next::method();
}

sub appconfig : Local {
    my ( $self, $c, $var ) = @_;
    $c->res->body( $c->config->{ $var } );
}

1;
