package Catalyst::Plugin::ConfigLoader::CLSource;

use Moo;
use MooX::HandlesVia;
use namespace::clean;
use File::Basename qw/fileparse/;
use File::Spec::Functions qw/catfile/;

extends "Config::Loader::Source::Profile::Default";

has name => ( is => "ro" );

## Does the following:
##
## 1: Checks %ENV for a possible override of filename
##
## 2: Checks for existance of a possible _local file to add after main
## file
##

## General challenge:
##
## 1: There may be File sources
##
## 2: There may be overrides to File. Presence of overrides will
## discard any File source arguments
##
## Strategy: Create one File source for each file. Set overrides to
## apply config to all
##

before _build_loader => sub {

    my $self = shift;

    ## Do the %ENV
    if ( defined ( my $path = Catalyst::Utils::env_value( $self->name, 'CONFIG' ))) {

        ## Delete any override that contains "file"
        my %file_args = %{ delete($self->overrides->{File}) // {} };
        delete $file_args{file};

        ## This now should be the only File source
        my @non_file_sources = grep { $_->[0] ne "File" } @{ $self->sources };

        unshift @non_file_sources, [ File => { %file_args, file => $path } ];
        $self->{sources} = \@non_file_sources;

    }

    ## Do the _local

    my $local_suffix = defined $self->name ?
        $ENV{ uc $self->name . '_CONFIG_LOCAL_SUFFIX' } // "local" : "local";

    ## If a file exists in the override, grab it and delete it
    if ( exists $self->overrides->{File} ) {

        ## Pluck out the file
        my $file = delete $self->overrides->{File}{file};
        my %file_args = my %file_args_local = %{ $self->overrides->{File} };

        delete $self->overrides->{File};

        ## There should now be no other File sources
        my @non_file_sources = grep { $_->[0] ne "File" } @{ $self->{sources} };

        push @non_file_sources, [ File => { %file_args,
                                            file => $file } ];
        push @non_file_sources, [ File => { %file_args_local,
                                            file => _local_suffixed_filepath($file, $local_suffix) } ];

        $self->{sources} = \@non_file_sources;

    }
    else {

        my @local_sources;

        for my $source (@{$self->sources}) {

            if ( $source->[0] eq "File" ) {

                if ( exists $source->[1]{file} ) {

                    my %source_args = %{$source->[1]};
                    my $file = delete $source_args{file};

                    $source_args{file} = _local_suffixed_filepath($file, $local_suffix);

                    push @local_sources,
                        [ File => { %source_args } ];

                }

            }
        }

        push @{$self->sources}, @local_sources;

    }

};

sub _local_suffixed_filepath {

    my ($file,$local_suffix) = (shift,shift);

    die "local_suffix missing" unless defined $local_suffix;

    ## This assumes $file is a file or a stem. Cases where it
    ## is a directory needs to be explored later
    my( $name, $dirs, $suffix ) = fileparse( $file, qr/\.[^.]*/ );

    my $new_with_local = $name . "_" . $local_suffix;

    my $new_local_file = catfile( $dirs, $new_with_local );

    $new_local_file .= $suffix ? $suffix : "";

    return $new_local_file;

}

# sub get_config_local_suffix {
#     my $c = shift;

#     my $appname = ref $c || $c;
#     my $suffix = Catalyst::Utils::env_value( $appname, 'CONFIG_LOCAL_SUFFIX' )
#         || $c->config->{ 'Plugin::ConfigLoader' }->{ config_local_suffix }
#         || 'local';

#     return $suffix;
# }


1;
