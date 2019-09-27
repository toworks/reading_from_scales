package schenck;{ 
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
  my $REQUEST;# = "00#TG#";

  sub read {
	my ($self) = @_;

	if ( defined($self->{serial}->{connection}) ) {
		$self->{connection} = $self->{serial}->{connection};
	}

	$REQUEST = $self->{serial}->{scale}->{id} . "#" .$self->{serial}->{scale}->{command}. "#";

	$self->{log}->save('d', "scales id: $self->{serial}->{scale}->{id}".
							"  command: $self->{serial}->{scale}->{command}") if $self->{serial}->{'DEBUG'};
	$self->{log}->save('d', "type connection: $self->{serial}->{connection}") if $self->{serial}->{'DEBUG'};

	my $message = $STX.$REQUEST.$DLE.$ETX.hash_bcc($REQUEST.$DLE.$ETX);

	$self->{log}->save('d', "request: $message") if $self->{serial}->{'DEBUG'};
	$self->{log}->save('d', "request as hex: " . unpack "H*", $message) if $self->{serial}->{'DEBUG'};

	my ($count, $readline);

	if ( $self->{connection} =~ /serial/ ) {
		$self->connect() if $self->get('error') == 1;

		return if $self->get('error') == 1;

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

	return $self->processing($readline);
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

  sub processing {
	my ($self, $raw) = @_;
	my @array;
	$raw =~ s/\s//g;
	$raw =~ s/[$STX$DLE$ETX]//g;
	$raw =~ s/#\W$//g;
	$raw =~ s/^$REQUEST//g;
	$self->{log}->save('d', "processing raw: $raw") if $self->{serial}->{'DEBUG'};
	@array = split("#", $raw);
	$self->{log}->save('d', "array: ".Dumper(@array)) if $self->{serial}->{'DEBUG'};
	return $self->get_weight(\@array);
  }

  sub get_weight {
	my ($self, $raw) = @_;
	my $weight;
	foreach my $measure ( keys %{$self->{serial}->{'measuring'}} ) {
		if ( $measure =~ /in/ ) {
			foreach my $type ( keys %{$self->{serial}->{'measuring'}->{$measure}} ) {
				my $bit = $self->{serial}->{'measuring'}->{$measure}->{$type}->{bit} - 1;
				if ( $type =~ /weight/ ) {
					$weight = $raw->[$bit] * $self->{serial}->{'scale'}->{coefficient} if defined($raw->[$bit]);
					print "$type: ", $weight, "\n" if $self->{serial}->{'DEBUG'};
				}
			}
		}
	}
	return 	$weight;
  }

  sub net_read {
	my ($self, $message) = @_;

	use IO::Socket::INET;

	$| = 1;

	$self->{log}->save('d', "host: ".$self->{serial}->{host}.
							" port: ".$self->{serial}->{port}.
							" protocol: ".$self->{serial}->{protocol}) if $self->{serial}->{'DEBUG'};

	my ($socket, $response);

	eval {
		$socket = new IO::Socket::INET (
		PeerHost   => $self->{serial}->{host},
		PeerPort   => $self->{serial}->{port},
		Proto      => $self->{serial}->{protocol},
		Timeout    => 5,
#		Blocking => 0,
		) || die "$!";
	};
	if($@) {
		$self->{log}->save("e", "$@");
		return;
	};

	eval {
		my $size = $socket->send($message);
		print "sent data of length $size\n" if $self->{serial}->{'DEBUG'};
	};
	if($@) { $self->{log}->save("e", "$@") };
	
	# notify server that request has been sent
	shutdown($socket, 1);
	
	use IO::Select;

	my $select = new IO::Select();
	$select->add($socket);
	my @socket = $select->can_read(1);
	if (@socket == 1) {
		$socket->recv($response, 1024);
		print "received response: $response\n" if $self->{serial}->{'DEBUG'};
	}
	$socket->close();

	return $response || "";
  }
}
1;
