#!/usr/bin/perl -w

use strict;
use IO::Socket;

my $port = 4001;
my $server = 'localhost';

# data
my $ETX = "\r";
my $first;
my $XZ_Z = '1001'.'0010'.'0000'.'0000'; # статус весов zero
my $XZ_S = '1000'.'0110'.'0000'.'0000'; # статус весов stab
my @DC = (0.991, 0.992, 0.993, 0.994, 0.995, 0.996, 0.997, 0.998); # коэффициент калибровки угла
my @DP = (2401, 2402, 2403, 2404, 2405, 2406, 2407, 2408); # значение (points) ячейки
my $YP = 50000; # вес нетто без едениц измерений

# Создаем сокет
my $socket = IO::Socket::INET->new(	LocalAddr  => $server,
									LocalPort  => $port,
									Proto     => "tcp",
									Type      => SOCK_STREAM,
									Reuse 	  => 1,
									Listen 	  => 10 ) # or SOMAXCONN
									or die "Couldn't be a tcp server on port $port : $@\n";

while (my $client = $socket->accept()) {
   my $client_address = $client->peerhost();
   my $client_port = $client->peerport();
	
   print "connect client: $client_address port: $client_port", "\n";
   
   while (my $data = <$client>) {
		print ">>>>>>>>>>>>>>\n";
		print "received do: ", $data, "\n";
		$data =~ s/\r//g;
		if ( $data =~ /XZ/ ) {
			my $XZ = &bintohex($XZ_Z) if ! defined($first);
			$XZ = &bintohex($XZ_S) if defined($first);
			$first = 1 if ! defined($first);
			print "received: ", $data, "\n";
			print "send: ", $XZ.$ETX, "\n";
			$client->send($XZ.$ETX);
		}
		if ( $data =~ /DC/ ) {
			print "received: ", $data, "\n";
			$data =~ s/\D+//g;
			print "send: ", $DC[$data-1].$ETX, "\n";
			$client->send($DC[$data-1].$ETX);
		}
		if ( $data =~ /DP/ ) {
			print "received: ", $data, "\n";
			$data =~ s/\D+//g;
			print "send: ", $DP[$data-1].$ETX, "\n";
			$client->send($DP[$data-1].$ETX);
		}
		if ( $data =~ /YP/ ) {
			print "received: ", $data, "\n";
			print "send: ", $YP.$ETX, "\n";
			$client->send($YP.$ETX);
		}
		print "received post: ", $data, "\n";
		print "<<<<<<<<<<<<<<\n";
   }
   $client->close();
}

sub bintohex {
	my($bin) = @_;
	my $int = unpack("N", pack("B32", substr("0" x 32 . $bin, -32)));
	my $hex = sprintf("%x", $int);
	return $hex;
}