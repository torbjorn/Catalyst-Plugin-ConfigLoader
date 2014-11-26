package Catalyst::Plugin::ConfigLoader;

use strict;
use warnings;

use Config::Any;
use MRO::Compat;
use Data::Visitor::Callback;
use Catalyst::Utils ();

use Config::Loader ();

our $VERSION = '0.32';

sub setup {

    my $c = shift;

    my $appname = ref $c || $c;

    my $env_info = Config::Loader->new_source
        ( 'ENV',
          env_prefix => $appname,
          env_search => [qw/config config_local_suffix/]
      )->load_config;
    my ($env_path,$env_suffix) = @{$env_info}{
        (
            "${appname}_config",
            "${appname_config_local_suffix}"
        )};

    my $prefix  = Catalyst::Utils::appprefix( $appname );

    my $path    = $c->config->{ 'Plugin::ConfigLoader' }->{ file }
        || $c->path_to( $prefix ) || $env_path

    if ( -d $path ) {
        $path .= "/$prefix";
    }

    my $cl = Config::Loader->new_source(

        FileWithLocal => {
            file => $path,
            defined $env_suffix ? (local_suffix => $env_suffix) : (),
            load_args   => {
                filter      => \&_fix_syntax,
                use_ext     => 1,
                driver_args => $c->config->{ 'Plugin::ConfigLoader' }->{ driver }
            }
        },

    );
    my $s = Config::Loader->new_source(
        'Filter::Substitution',
        source => $cl,
        substitutions => {

            ## defaults:
            HOME => sub { $c->path_to( '' ); },
            ENV =>  sub {
                shift;
                my ($v) = @_;
                if ( !defined $v) {
                    return '';
                }
                if (! defined($ENV{$v})) {
                    Catalyst::Exception->throw( message => "Missing environment variable: $v" );
                    return '';
                } else {
                    return $ENV{ $v };
                }
            },
            path_to => sub { shift; $c->path_to( @_ ); },
            literal => sub { return $_[ 1 ]; },

            ## configured:
            %{ $c->config->{ 'Plugin::ConfigLoader' }->{ substitutions } || {} },

        }
    );

    $c->config( $s->load_config );

    if ( $c->debug ) {
        for (grep -r, ($cl->loaded_files) ) {
            $c->log->debug( qq(Loaded Config "$_") )
        }
    }

    $c->finalize_config;
    $c->next::method( @_ );

}

sub _fix_syntax {
    my $config     = shift;
    my @components = (
        map +{
            prefix => $_ eq 'Component' ? '' : $_ . '::',
            values => delete $config->{ lc $_ } || delete $config->{ $_ }
        },
        grep { ref $config->{ lc $_ } || ref $config->{ $_ } }
            qw( Component Model M View V Controller C Plugin )
    );

    foreach my $comp ( @components ) {
        my $prefix = $comp->{ prefix };
        foreach my $element ( keys %{ $comp->{ values } } ) {
            $config->{ "$prefix$element" } = $comp->{ values }->{ $element };
        }
    }
}

sub finalize_config {}

1;

__END__

=head1 NAME

Catalyst::Plugin::ConfigLoader - Load config files of various types

=head1 SYNOPSIS

    package MyApp;

    # ConfigLoader should be first in your list so
    # other plugins can get the config information
    use Catalyst qw( ConfigLoader ... );

    # by default myapp.* will be loaded
    # you can specify a file if you'd like
    __PACKAGE__->config( 'Plugin::ConfigLoader' => { file => 'config.yaml' } );

  In the file, assuming it's in YAML format:

    foo: bar

  Accessible through the context object, or the class itself

   $c->config->{foo}    # bar
   MyApp->config->{foo} # bar

=head1 DESCRIPTION

This module will attempt to load find and load a configuration
file of various types. Currently it supports YAML, JSON, XML,
INI and Perl formats. Special configuration for a particular driver format can
be stored in C<MyApp-E<gt>config-E<gt>{ 'Plugin::ConfigLoader' }-E<gt>{ driver }>.
For example, to pass arguments to L<Config::General>, use the following:

    __PACKAGE__->config( 'Plugin::ConfigLoader' => {
        driver => {
            'General' => { -LowerCaseNames => 1 }
        }
    } );

See L<Config::Any>'s C<driver_args> parameter for more information.

To support the distinction between development and production environments,
this module will also attemp to load a local config (e.g. myapp_local.yaml)
which will override any duplicate settings.  See
L<get_config_local_suffix|/get_config_local_suffix>
for details on how this is configured.

=head1 METHODS

=head2 setup( )

This method is automatically called by Catalyst's setup routine. It will
attempt to use each plugin and, once a file has been successfully
loaded, set the C<config()> section.

=head2 find_files

This method determines the potential file paths to be used for config loading.
It returns an array of paths (up to the filename less the extension) to pass to
L<Config::Any|Config::Any> for loading.

=head2 get_config_path

This method determines the path, filename prefix and file extension to be used
for config loading. It returns the path (up to the filename less the
extension) to check and the specific extension to use (if it was specified).

The order of preference is specified as:

=over 4

=item * C<$ENV{ MYAPP_CONFIG }>

=item * C<$ENV{ CATALYST_CONFIG }>

=item * C<$c-E<gt>config-E<gt>{ 'Plugin::ConfigLoader' }-E<gt>{ file }>

=item * C<$c-E<gt>path_to( $application_prefix )>

=back

If either of the first two user-specified options are directories, the
application prefix will be added on to the end of the path.

=head2 finalize_config

This method is called after the config file is loaded. It can be
used to implement tuning of config values that can only be done
at runtime. If you need to do this to properly configure any
plugins, it's important to load ConfigLoader before them.
ConfigLoader provides a default finalize_config method which
walks through the loaded config hash and calls the C<config_substitutions>
sub on any string.

=head2 config_substitutions( $value )

This method substitutes macros found with calls to a function. There are a
number of default macros:

=over 4

=item * C<__HOME__> - replaced with C<$c-E<gt>path_to('')>

=item * C<__ENV(foo)__> - replaced with the value of C<$ENV{foo}>

=item * C<__path_to(foo/bar)__> - replaced with C<$c-E<gt>path_to('foo/bar')>

=item * C<__literal(__FOO__)__> - leaves __FOO__ alone (allows you to use
C<__DATA__> as a config value, for example)

=back

The parameter list is split on comma (C<,>). You can override this method to
do your own string munging, or you can define your own macros in
C<MyApp-E<gt>config-E<gt>{ 'Plugin::ConfigLoader' }-E<gt>{ substitutions }>.
Example:

    MyApp->config->{ 'Plugin::ConfigLoader' }->{ substitutions } = {
        baz => sub { my $c = shift; qux( @_ ); }
    }

The above will respond to C<__baz(x,y)__> in config strings.

=head2 get_config_local_suffix

Determines the suffix of files used to override the main config. By default
this value is C<local>, which will load C<myapp_local.conf>.  The suffix can
be specified in the following order of preference:

=over 4

=item * C<$ENV{ MYAPP_CONFIG_LOCAL_SUFFIX }>

=item * C<$ENV{ CATALYST_CONFIG_LOCAL_SUFFIX }>

=item * C<$c-E<gt>config-E<gt>{ 'Plugin::ConfigLoader' }-E<gt>{ config_local_suffix }>

=back

The first one of these values found replaces the default of C<local> in the
name of the local config file to be loaded.

For example, if C< $ENV{ MYAPP_CONFIG_LOCAL_SUFFIX }> is set to C<testing>,
ConfigLoader will try and load C<myapp_testing.conf> instead of
C<myapp_local.conf>.

=head1 AUTHOR

Brian Cassidy E<lt>bricas@cpan.orgE<gt>

=head1 CONTRIBUTORS

The following people have generously donated their time to the
development of this module:

=over 4

=item * Joel Bernstein E<lt>rataxis@cpan.orgE<gt> - Rewrite to use L<Config::Any>

=item * David Kamholz E<lt>dkamholz@cpan.orgE<gt> - L<Data::Visitor> integration

=item * Stuart Watt - Addition of ENV macro.

=back

Work to this module has been generously sponsored by:

=over 4

=item * Portugal Telecom L<http://www.sapo.pt/> - Work done by Joel Bernstein

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2010 by Brian Cassidy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item * L<Catalyst>

=item * L<Catalyst::Plugin::ConfigLoader::Manual>

=item * L<Config::Any>

=back
