package mika;{ 
  use strict;
  use warnings;
  use utf8;
  use lib 'libs';
  use parent "serial";
  use Data::Dumper;

#	протокол: ASCII
#	информация: none
#	контроллер: МИКА КВ 2

  my $ETX = "\r";
  my $REQUEST;

  sub read {
	my ($self) = @_;

	if ( defined($self->{serial}->{connection}) ) {
		$self->{connection} = $self->{serial}->{connection};
	}

	$self->{log}->save('d', "connection type: " . $self->{connection} ) if $self->{serial}->{'DEBUG'};

	$REQUEST = $self->{serial}->{'scale'}->{command} . $ETX;

	$self->{log}->save('d', "command: $self->{serial}->{'scale'}->{command}") if $self->{serial}->{'DEBUG'};
	$self->{log}->save('d', "type connection: $self->{serial}->{connection}") if $self->{serial}->{'DEBUG'};

	$self->{log}->save('d', "request: $REQUEST") if $self->{serial}->{'DEBUG'};

	my ($count, $readline);

	if ( $self->{connection} =~ /serial/ ) {
		$self->connect() if $self->get('error') == 1;
		
		return if $self->get('error') == 1;

		#eval{ $readline = $self->{fh}->input || die "$!"; };
		#if($@) { $self->{log}->save("e", "$@") };

		eval{ $readline = $self->{fh}->write($REQUEST) || die "$!"; };
		if($@) { $self->{log}->save("e", "$@") };

		$self->{log}->save('d', "request count: $readline") if $self->{serial}->{'DEBUG'};
		eval{ $readline = $self->{fh}->read(255) || die "$!"; };
		if($@) { $self->{log}->save("e", "$@") };
		$self->{log}->save('d', "answer: $readline") if $self->{serial}->{'DEBUG'};
	} else {
		$readline = $self->net_read($REQUEST);
	}

	return $self->processing($readline);
  }

  sub processing {
	my ($self, $raw) = @_;
	my $weight;
	$self->{log}->save('d', "processing raw: $raw") if $self->{serial}->{'DEBUG'};
	$raw =~ s/(\s)*(-)(\s)*/ $2/; # join numeric and minus
	if ($raw =~ /[k\|g]/) {
		($self->{answer}->{command}, $self->{answer}->{weight}, $self->{answer}->{unit}) = split(" ", $raw);
	} else {
		$raw =~ s/\s*//g;
		$self->{answer}->{weight} = $raw;
	}
	$self->{log}->save('d', "answer:    command: '".$self->{answer}->{command}."'  ".
							"weight: '".$self->{answer}->{weight}."'  ".
							"unit: '".$self->{answer}->{unit}."'"
	) if $self->{serial}->{'DEBUG'};

	if ( $self->{serial}->{'scale'}->{command} eq $self->{answer}->{command} and
		 $self->{answer}->{weight} =~ /^[-0-9,.E]+$/
	 ) {
		$self->{answer}->{weight} =~ s/,//g;
		$self->{log}->save('d', "stable weight: ".$self->{answer}->{weight}) if $self->{serial}->{'DEBUG'};
		if ( $self->{answer}->{unit} eq 'k' ) {
			$weight = $raw = $self->{answer}->{weight};
		} elsif ( $self->{answer}->{unit} eq 'g' ) {
			$weight = $self->{answer}->{weight} * $self->{serial}->{'scale'}->{coefficient};
		}
	}
	if ( ! defined($self->{answer}->{command}) and ! defined($self->{answer}->{unit}) ) {
		$weight = $self->{answer}->{weight};
	}

	return $weight;
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
