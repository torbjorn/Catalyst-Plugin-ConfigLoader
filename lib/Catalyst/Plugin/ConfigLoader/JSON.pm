package Catalyst::Plugin::ConfigLoader::JSON;

use strict;
use warnings;

use File::Slurp;

=head1 NAME

Catalyst::Plugin::ConfigLoader::JSON - Load JSON config files

=head1 DESCRIPTION

Loads JSON files. Example:

    {
        "name": "TestApp",
        "Controller::Foo": {
            "foo": "bar"
        }
    }

=head1 METHODS

=head2 extensions( )

return an array of valid extensions (C<json>, C<jsn>).

=cut

sub extensions {
    return qw( json jsn );
}

=head2 load( $file )

Attempts to load C<$file> as a JSON file.

=cut

sub load {
    my $class = shift;
    my $file  = shift;

    my $content = read_file( $file );

    eval { require JSON::Syck; };
    if( $@ ) {
        require JSON;
        JSON->import;
        return jsonToObj( $content );
    }
    else {
        return JSON::Syck::Load( $content );
    }
}

=head1 AUTHOR

=over 4 

=item * Brian Cassidy E<lt>bricas@cpan.orgE<gt>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Brian Cassidy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 SEE ALSO

=over 4 

=item * L<Catalyst>

=item * <Catalyst::Plugin::ConfigLoader>

=back

=cut

1;