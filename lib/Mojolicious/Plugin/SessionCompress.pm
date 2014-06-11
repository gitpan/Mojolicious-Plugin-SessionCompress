package Mojolicious::Plugin::SessionCompress;
use Mojo::Base 'Mojolicious::Plugin';
use Mojolicious::Sessions;
use Mojo::Util ();
use Mojo::JSON ();
use Compress::Zlib ();

our $VERSION = '0.01';

sub register {
  my ($self, $app, $conf) = @_;
  $conf ||= {};
  my ($compress, $decompress, $serialize, $deserialize);

  my $min_size = exists $conf->{min_size} ? delete $conf->{min_size} : 250;
  if (exists $conf->{compress} && exists $conf->{decompress}) {
    $compress = delete $conf->{compress};
    $decompress = delete $conf->{decompress};
  } else {
    $compress = sub {
      my $string = shift;

      my $d = Compress::Zlib::deflateInit(-Level => 1, -memLevel => 5, -WindowBits => -15);
      return $d->deflate($string) . $d->flush;
    };

    $decompress = sub {
      my $string = $_[0];

      my $d = Compress::Zlib::inflateInit(-WindowBits => -15);
      my ($inflated, $status) = $d->inflate($string);
      return $_[0] if $status != Compress::Zlib::Z_STREAM_END; # Check to see if it's actually compressed
      return $inflated;
    };
  }

  if (exists $conf->{serialize} && exists $conf->{deserialize}) {
    $serialize = delete $conf->{serialize};
    $deserialize = delete $conf->{deserialize};
  } else {
    $serialize = \&Mojo::JSON::encode_json;
    $deserialize = \&Mojo::JSON::j;
  }

  Mojo::Util::monkey_patch 'Mojolicious::Sessions',
    encode_json => sub {
      my $hashref = shift;

      my $serialized = $serialize->($hashref);
      return $serialized if (length $serialized < $min_size);
      return $compress->($serialized);
    },
    j => sub {
      my $string = shift;

      return $deserialize->($decompress->($string));
    };
}

1;
__END__


=head1 NAME

Mojolicious::Plugin::SessionCompress - Session serialization and compression plugin for Mojolicious

=head1 SYNOPSIS

    # Default settings

    plugin 'SessionCompress';

    # Custom settings

    use Compress::Zlib qw(memGzip memGunzip);
    use Data::Dumper 'Dumper';
    $Data::Dumper::Terse = 1;

    plugin session_compress => {
        compress => sub { goto &memGzip },
        decompress => sub {
            my $string = shift;

            return $out if ($out = memGunzip($string));
            return $string;
        },
        serialize => sub { goto &Dumper },
        deserialize => sub {
            my $string = shift;

            return eval $string;
        },
        min_size => 75
    };

=head2 C<compress>

    # This and the following are the defaults used internally
    compress => sub {
        my $string = shift;

        my $d = Compress::Zlib::deflateInit(-Level => 1, -memLevel => 5, -WindowBits => -15);
        return $d->deflate($string) . $d->flush;
    }

=head2 C<decompress>

    decompress => sub {
        my $string = $_[0];

        my $d = Compress::Zlib::inflateInit(-WindowBits => -15);
        my ($inflated, $status) = $d->inflate($string);
        return $_[0] if $status != Compress::Zlib::Z_STREAM_END; # Check to see if it's actually compressed
        return $inflated;
    }

=head2 C<serialize>

    serialize => \&Mojo::JSON::encode_json

=head2 C<deserialze>

    deserialize > \&Mojo::JSON::j

=head2 C<min_size>

    min_size minimum size that's allowed to be compressed

    min_size => 250

=head1 CAVEATS

Mojolicious::Plugin::SessionCompress relies on Mojo::Util::monkey_patch to override j and encode_json within
Mojolicious::Sessions. This may seem hack-y to some. Always test your app after installing a new version of
Mojolicious.

=head1 SEE ALSO

[Mojolicious](http://search.cpan.org/perldoc?Mojolicious), [Compress::Zlib](http://search.cpan.org/perldoc?Compress::Zlib)

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Sean Ohashi.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License 2.0.

=cut