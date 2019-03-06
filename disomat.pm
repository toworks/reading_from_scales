package disomat;{ 
use strict;
  use warnings;
  use utf8;
  use lib 'libs';
  use parent "serial";
  use Data::Dumper;

#	протокол: SCHENCK Poll Protocol (DDP 8785)
#	информация: bvh2141gb.pdf
#	контроллер: DISOMAT B plus

  my $STX = pack "c1", 0x02;
  my $ETX = pack "c1", 0x03;
  my $DLE = pack "c1", 0x10;
  my $REQUEST = "00#TK#";

  sub read {
	my ($self) = @_;

	$self->{log}->save('d', "type connection: $self->{serial}->{connection}") if $self->{serial}->{'DEBUG'};

	my $message = $STX.$REQUEST.$DLE.$ETX.hash_bcc($REQUEST.$DLE.$ETX);

	$self->{log}->save('d', "request: $message") if $self->{serial}->{'DEBUG'};
	$self->{log}->save('d', "request as hex: " . unpack "H*", $message) if $self->{serial}->{'DEBUG'};

	my ($count, $readline);

	if ( $self->{serial}->{connection} =~ /serial/ ) {
		$self->connect() if $self->get('error') == 1;
			
		#eval{ $readline = $self->{fh}->input || die "$!"; };
		#if($@) { $self->{log}->save("e", "$@") };
		
		eval{ $readline = $self->{fh}->write($message) || die "$!"; };
		if($@) { $self->{log}->save("e", "$@") };

		$self->{log}->save('d', "request count: $readline") if $self->{serial}->{'DEBUG'};
		eval{ $readline = $self->{fh}->read(255) || die "$!"; };
		if($@) { $self->{log}->save("e", "$@") };
		$self->{log}->save('d', "answer: $readline") if $self->{serial}->{'DEBUG'};
	} else {
		$readline = $self->net_read($message);
	}
	
	$self->measuring_in($readline);
	
	return $readline;
  }

  sub hash_bcc {
	my ($in) = shift;
	my @array = split('', $in);
#	print Dumper(@array);
	my $total = $array[0];
	for ( my $i=1; $i <= $#array ; $i++) {
		$total = chr(ord($total) ^ ord($array[$i]));
#		print $total, " | $i\n";
	}
	return $total;
  }

  sub measuring_in {
	my ($self, $in) = @_;
	$in =~ s/\s//g;
	$in =~ s/[$STX$DLE$ETX]//g;
	$in =~ s/#\W$//g;
	$in =~ s/^$REQUEST//g;
	$self->{log}->save('d', "in: $in") if $self->{serial}->{'DEBUG'};
	$self->{serial}->{measuring}->{in} = [split("#", $in)];
	$self->{log}->save('d', "array: ".Dumper($self->{serial}->{measuring}->{in})) if $self->{serial}->{'DEBUG'};
  }

  sub net_read {
	my ($self, $message) = @_;

	use IO::Socket::INET;

	$| = 1;

	$self->{log}->save('d', "host: ".$self->{serial}->{host}.
							" port: ".$self->{serial}->{port}.
							" protocol: ".$self->{serial}->{protocol}) if $self->{serial}->{'DEBUG'};

	my $socket;

	eval {
		$socket = new IO::Socket::INET (
		PeerHost => $self->{serial}->{host},
		PeerPort => $self->{serial}->{port},
		Proto => $self->{serial}->{protocol},
		) || die "$!";
	};
	if($@) { $self->{log}->save("e", "$@") };
	
	#print "connected to the server\n";
 
	# data to send to a server
	#my $req = 'hello world';
	my $size = $socket->send($message);
	print "sent data of length $size\n";
	 
	# notify server that request has been sent
	shutdown($socket, 1);
	 
	# receive a response of up to 1024 characters from server
	my $response = "";
	$socket->recv($response, 1024);
	print "received response: $response\n";
	 
	$socket->close();
	return $response;
  }
}
1;
