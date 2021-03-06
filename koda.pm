package koda;{ 
  use strict;
  use warnings;
  use utf8;
  use lib 'libs';
  use parent "serial";
  use Data::Dumper;

#	протокол: ASCII
#	информация: none
#	контроллер: KODA-IV

  my $STX = 'cc';
  my $ETX = 'c3';

  sub read {
	my ($self) = @_;

	if ( defined($self->{serial}->{connection}) ) {
		$self->{connection} = $self->{serial}->{connection};
	}

	$self->{log}->save('d', "connection type: " . $self->{connection} ) if $self->{serial}->{'DEBUG'};
	$self->{log}->save('d', "type connection: $self->{serial}->{connection}") if $self->{serial}->{'DEBUG'};

	my ($count, $readline, $msg);

	if ( $self->{connection} =~ /serial/ ) {
		$self->connect() if $self->get('error') == 1;
		
		return if $self->get('error') == 1;

		#eval{ $readline = $self->{fh}->input || die "$!"; };
		#if($@) { $self->{log}->save("e", "$@") };

#		eval{ $readline = $self->{fh}->write($REQUEST) || die "$!"; };
#		if($@) { $self->{log}->save("e", "$@") };

#		$self->{log}->save('d', "request count: $readline") if $self->{serial}->{'DEBUG'};
		eval{ 
				my $s = 0;
				my $c = 0;
				while ($c == 0) {
					$readline = $self->{fh}->read(255) || die "$!";
					my @bytes = map { unpack('H*', $_) } ($readline =~ /(.)/g);
					foreach my $_hex (@bytes) {
						if ( ($_hex =~ /$STX/ and $s == 0) or $s == 1 ) {
							$msg .= $_hex;
							$s = 1;
						}
						if ( $_hex =~ /$ETX/ and $s == 1 ) {
							$s = 0;
							$c = 1;
							$readline = $msg;
							last;
						}
					}
				}
		};
		if($@) { $self->{log}->save("e", "$@") };
	} else {
		$readline = $self->net_read();
	}

	$self->{log}->save('d', "answer: $readline") if $self->{serial}->{'DEBUG'};

	return $self->processing($readline);
  }

  sub processing {
	my ($self, $raw) = @_;
	my @weight;

	#my @_raw = map {  sprintf("%d", hex($_)) } ($raw =~ /(.)/g);
	my @_raw = map {  sprintf("%b", hex($_)) } ($raw =~ /(.)/g);

	#$self->{log}->save('d', "processing raw decimal: " . join(" | ", @_raw) ) if $self->{serial}->{'DEBUG'};
	$self->{log}->save('d', "processing raw bin: " . join(" | ", @_raw) ) if $self->{serial}->{'DEBUG'};

	my $const = 512;
	push @weight, $_raw[2]  * $const + $_raw[3] * 4 + (($_raw[18] >> 5) & 3);
	push @weight, $_raw[4]  * $const + $_raw[5] * 4 + (($_raw[18] >> 3) & 3);
	push @weight, $_raw[6]  * $const + $_raw[7] * 4 + (($_raw[18] >> 1) & 3);
	push @weight, $_raw[8]  * $const + $_raw[9] * 4 + (($_raw[18] >> 1) & 2) + (($_raw[19] >> 6) & 1);
	push @weight, $_raw[10] * $const + $_raw[11] * 4 + (($_raw[19] >> 4) & 3);
	push @weight, $_raw[12] * $const + $_raw[13] * 4 + (($_raw[19] >> 2) & 3);
	push @weight, $_raw[14] * $const + $_raw[15] * 4 + ($_raw[19] & 3);
	push @weight, $_raw[16] * $const + $_raw[17] * 4 + (($_raw[20] >> 5) & 3);

	my $weight_platform1 =
	my $weight_platform2 =
	
	push @weight, $weight_platform1, $weight_platform2;
	
	$self->{log}->save('d', "processing weight: " . Dumper(@weight) ) if $self->{serial}->{'DEBUG'};

	return \@weight;
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
