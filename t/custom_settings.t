BEGIN {
  $ENV{MOJO_NO_IPV6} = 1;
}

use Test::More tests => 22;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mojolicious::Lite;
use Test::Mojo;

use Compress::Zlib qw(memGzip memGunzip);
use Data::Dumper 'Dumper';
$Data::Dumper::Terse = 1;


plugin session_compress => {
  compress => sub {
    ok(1, 'Used custom compress');
    goto &memGzip
  },
  decompress => sub {
    my $string = shift;

    ok(1, 'Used custom decompress');
    my $out;
    return $out if ($out = memGunzip($string));
    return $string;
  },
  serialize => sub {
    ok(1, 'Used custom serialize');
    goto &Dumper
  },
  deserialize => sub {
    my $string = shift;

    ok(1, 'Used custom deserialize');
    return eval $string;
  },
  min_size => 75
};

get '/sessionsmall' => sub {
  my $self = shift;

  return $self->render(text => 'Hello ' . $self->session('user_name')) if ($self->session('user_name'));
  $self->session(user_name => 'Small_user');
  $self->render(text => 'Session set');
};

get '/sessionbig' => sub {
  my $self = shift;

  return $self->render(text => 'Hello ' . $self->session('user_name')) if ($self->session('user_name'));
  $self->session(user_name => 'Big_user', big_session =>
    '3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679');
  $self->render(text => 'Session set');
};

my $t = Test::Mojo->new;
$t->get_ok('/sessionsmall')->status_is(200)->content_is('Session set');
$t->get_ok('/sessionsmall')->status_is(200)->content_is('Hello Small_user');
$t->reset_session;
$t->get_ok('/sessionbig')->status_is(200)->content_is('Session set');
$t->get_ok('/sessionbig')->status_is(200)->content_is('Hello Big_user');
done_testing();