#!/usr/bin/perl -w

use strict;
use IO::Socket;

my $port = 4001;
my $server = 'localhost';

# data
my $ETX = "\r";
my $first_count = 30;
my $XZ_Z = '1001'.'0110'.'0000'.'0000'; # статус весов zero
my $XZ_S = '1000'.'0000'.'0000'.'0000'; # статус весов stab
my @DC = (0.991, 0.992, 0.993, 0.994, 0.995, 0.996, 0.997, 0.998); # коэффициент калибровки угла
my @DP_Z = (2534, 6223, 5738, 3714, 1977, 2981, 5108, 4371); # значение (points) ячейки zero
my @DP_S = (50764, 45537, 79774, 80499, 2505, 3622, 68010, 53705); # значение (points) ячейки stab
my $YP = 61750; # вес нетто без едениц измерений

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
		if ( $first_count != 0 ) {
			print "++++ ZERO ++++\n";
		} else {
			print "++++ WEIGHT ++++\n";
		}
		print "received do: ", $data, "\n";
		$data =~ s/\r//g;
		if ( $data =~ /XZ/ ) {
			my $XZ;
			if ( $first_count != 0 ) {
				$XZ = &bintohex($XZ_Z);
			} else {
				$XZ = &bintohex($XZ_S);
			}
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
			my @DP;
			if ( $first_count != 0 ) {
				@DP = @DP_Z;
			} else {
				@DP = @DP_S;
			}
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
		$first_count-- if $first_count != 0;
   }
   $client->close();
}

sub bintohex {
	my($bin) = @_;
	my $int = unpack("N", pack("B32", substr("0" x 32 . $bin, -32)));
	my $hex = sprintf("%x", $int);
	return $hex;
}