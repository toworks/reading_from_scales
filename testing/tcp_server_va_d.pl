#!/usr/bin/perl

 use strict;
 use warnings;
 use utf8;
 #binmode(STDOUT,':utf8');
 #use open(':encoding(utf8)');
 use Data::Dumper;
 use threads;
 use IO::Socket::INET;

 my $message = '2397;05/07/23;15:01:30;       1;ss8855ss;;sss "ssssss";;sss "ssss";;ssss ssssssss;;     340;²ss  1            170kg;²ss  2            170kg;;;;;;;;;;;;;:;;;;';
 my $port = 4001;
 my @count;
 my $client_id;

# auto-flush on socket
$| = 1;

# creating a listening socket
my $socket = new IO::Socket::INET (
    LocalHost => '0.0.0.0',
    LocalPort => $port,
    Proto => 'tcp',
    Listen => 5,
    Reuse => 1
);
die "cannot create socket $!\n" unless $socket;
print "server waiting for client connection on port $port\n";

while(1)
{
    # waiting for a new client connection
    while (my $client_socket = $socket->accept()) {

    # get information about a newly connected client
    my $client_address = $client_socket->peerhost();
    my $client_port = $client_socket->peerport();
    print "connection from $client_address:$client_port\n";

    # read up to 1024 characters from the connected client
    my $data = "";
#    $client_socket->recv($data, 1024);
#    print "received data: $data\n";


#    while (100) {
#        print "loop message\n";
#        # write response data to the connected client
#        $client_socket->send($count++ . $message);
#        select undef, undef, undef, 1;
#    }
        $client_id++;
        threads->create( \&sender, \$client_socket, $client_id )->detach;
    }

    # notify client that response has been sent
#    shutdown($client_socket, 1);
}

$socket->close();

sub sender () {
    my ($socket, $client_id) = @_;

    $count[$client_id] = 0;

    while (1) {
        print "loop message\n";
        # write response data to the connected client
        eval {
            ${$socket}->send($count[$client_id] . $message) or die "$!";
            print($count[$client_id] . $message . "\n") or die "$!";
            select undef, undef, undef, 2;
            ${$socket}->send($count[$client_id] . ';;;;;;;;;;;;;;;;;;;') or die "$!";
        };
        print $@, "\n" if $@;
        $count[$client_id]++;
        select undef, undef, undef, 10;
    }
}

