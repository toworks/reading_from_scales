package blanciai;{ 
  use strict;
  use warnings;
  use utf8;
  use lib 'libs';
  use parent "serial";
  use Data::Dumper;

#	протокол: remote commands protocol
#	информация: none
#	контроллер: Blanciai D400

  my $ETX = "\r";
  my $REQUEST;

  sub read {
	my ($self) = @_;

	if ( defined($self->{serial}->{connection}) ) {
		$self->{connection} = $self->{serial}->{connection};
	}

	$self->{log}->save('d', "connection type: " . $self->{connection} ) if $self->{serial}->{'DEBUG'};

	my @weights;
	my %scales = %{$self->{serial}->{'scale'}->{'alias'}};
	foreach my $scale (sort {$scales{$a} <=> $scales{$b}} keys %scales ) {
		print "key: ", $scale, , "   val: ", $scales{$scale}, "\n";
		
		$REQUEST = $self->{serial}->{'scale'}->{command} . $scales{$scale} . $ETX;

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
		$weights[$scales{$scale}] = $self->processing($readline);
	}
	# remove 0 array variable
	splice @weights, 0, 1;
	$self->{log}->save('d', Dumper(@weights) ) if $self->{serial}->{'DEBUG'};
	return \@weights;
  }

  sub processing {
	my ($self, $raw) = @_;
	my $weight;
	$self->{log}->save('d', "processing raw: $raw") if $self->{serial}->{'DEBUG'};
	return if $raw !~ /(\s).*/;
	($self->{answer}->{weight}, $self->{answer}->{unit}, $self->{answer}->{command}) = split(" ", $raw);
	$self->{log}->save('d', "answer:    command: '".$self->{answer}->{command}."'  ".
							"weight: '".$self->{answer}->{weight}."'  ".
							"unit: '".$self->{answer}->{unit}."'"
	) if $self->{serial}->{'DEBUG'};


	$self->{answer}->{weight} =~ s/,//g;
	$self->{log}->save('d', "stable weight: ".$self->{answer}->{weight}) if $self->{serial}->{'DEBUG'};
	if ( $self->{answer}->{unit} =~ /kg/ ) {
		$weight = $self->{answer}->{weight};
	} elsif ( $self->{answer}->{unit} =~ /g/ ) {
		$weight = $self->{answer}->{weight} * $self->{serial}->{'scale'}->{coefficient};
	} elsif ( $self->{answer}->{unit} =~ /\A\z/ ) {
#		$weight = $self->{answer}->{weight} / $self->{serial}->{'scale'}->{coefficient};
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
