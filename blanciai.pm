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
  my $ANSWER;
  my %calc_params;


  sub read {
	my ($self) = @_;

	if ( defined($self->{serial}->{connection}) ) {
		$self->{connection} = $self->{serial}->{connection};
	}

	my (@weights, $command, $scales, $weight_platform1, $weight_platform2);

eval {

	$command = \%{$self->{serial}->{'scale'}->{'command'}};
	$scales = \%{$self->{serial}->{'scale'}->{'alias'}};

	print Dumper($command) if $self->{serial}->{'DEBUG'};

	$ANSWER = $self->_read($command->{'status'});
	my $zero = $self->get_status('zero', &clean($ANSWER));
	my $stab = $self->get_status('stab', &clean($ANSWER));

	# WghtT -> YP
	my $_command = $command->{'netto'};
	$ANSWER = $self->_read($_command);
	$calc_params{$_command} = &clean($ANSWER);

	foreach my $scale (sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
		# get cell: DP
		my $_command = $command->{'cell'} . $scales->{$scale};
		$ANSWER = $self->_read($_command);
		$calc_params{$scales->{$scale}}->{$_command} = &clean($ANSWER);

		if ( defined($zero) and $zero eq 1 and ! defined $calc_params{$scales->{$scale}}->{'zi'} ) {
			# get coefficient_angle: DC
			$_command = $command->{'coefficient_angle'} . $scales->{$scale};
			$ANSWER = $self->_read($_command);
			$ANSWER =~ /\s*([\d\.\,]+)\s*([\d\.\,]+)/; # get first value $1 - first  $2 - two
			$calc_params{$scales->{$scale}}->{$_command} = &clean($1);
	
			# pi = di*ki;
			$calc_params{$scales->{$scale}}->{'pi0'} =
						$calc_params{$scales->{$scale}}->{$command->{'cell'} . $scales->{$scale}} *
						$calc_params{$scales->{$scale}}->{$command->{'coefficient_angle'} . $scales->{$scale}};
			# При WghtT = 0 :  zi = pi;
			$calc_params{$scales->{$scale}}->{'zi'} = $calc_params{$scales->{$scale}}->{'pi0'};
		} elsif ( defined $calc_params{$scales->{$scale}}->{'zi'} ) {		
			# pi = di*ki;
			$calc_params{$scales->{$scale}}->{'pi'} =
						$calc_params{$scales->{$scale}}->{$command->{'cell'} . $scales->{$scale}} *
						$calc_params{$scales->{$scale}}->{$command->{'coefficient_angle'} . $scales->{$scale}};
			# pi = pi – zi;
			$calc_params{$scales->{$scale}}->{'pi'} = $calc_params{$scales->{$scale}}->{'pi'} -
													  $calc_params{$scales->{$scale}}->{'zi'};
		}
	}

	# clean Ps
	$calc_params{'Ps'} = 0;
				
	foreach my $scale (sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
		if ( $zero ne 1 and defined($calc_params{$scales->{$scale}}->{'zi'}) ) {
			$self->{log}->save('d', "Ps p". $scales->{$scale} .": ". $calc_params{$scales->{$scale}}->{'pi'}) if $self->{serial}->{'DEBUG'};
			# Ps = pi+pi+pi+pi+pi+pi+pi+pi;
			$calc_params{'Ps'} += $calc_params{$scales->{$scale}}->{'pi'};
		}
	}

	if ( $zero ne 1 ){	
		foreach my $scale (sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
			# ki = Ps/pi;
			$calc_params{$scales->{$scale}}->{'ki'} = $calc_params{'Ps'} /
													  $calc_params{$scales->{$scale}}->{'pi'};
			# wi = WghtT/ki
			$calc_params{$scales->{$scale}}->{'wi'} = $calc_params{'YP'} /
													  $calc_params{$scales->{$scale}}->{'ki'};
			if ( defined $calc_params{$scales->{$scale}}->{'wi'} ) {
				# wi write to array for sql
				$weights[$scales->{$scale}] = sprintf("%.0f", $calc_params{$scales->{$scale}}->{'wi'} * $self->{serial}->{'scale'}->{coefficient} );
				# weight platforms
				$weight_platform1 += $weights[$scales->{$scale}] if ( $scales->{$scale} <= 4 );
				$weight_platform2 += $weights[$scales->{$scale}] if ( $scales->{$scale} > 4 and $scales->{$scale} <= 8 );
			}
		}
	}
	
	print Dumper(\%calc_params) if $self->{serial}->{'DEBUG'};
	$self->{log}->save('d', "calc_params: ". Dumper(\%calc_params)) if $self->{serial}->{'DEBUG'};

	if ( ! defined($calc_params{'Ps'}) ) {
		foreach my $scale (sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
			$weights[$scales->{$scale}] = 0;
		}
		#push @weights, sprintf("%.0f", (62.65 + 97.546 + 130 + 196) * $self->{serial}->{'scale'}->{coefficient}), (2 + (-8) + (-240) + (-154)) * $self->{serial}->{'scale'}->{coefficient};
		push @weights, 0, 0;
	} else {
		push @weights, $weight_platform1, $weight_platform2;
	}

	# remove 0 array variable
	splice @weights, 0, 1;# if $zero != 1;
};
	$self->{log}->save('d', Dumper(@weights) ) if $self->{serial}->{'DEBUG'};
	
	if ( @weights ) {
		return \@weights;
	} else {
		return undef;
	}
  }

  sub _read {
	my ($self, $command) = @_;

	if ( defined($self->{serial}->{connection}) ) {
		$self->{connection} = $self->{serial}->{connection};
	}

	$self->{log}->save('d', "connection type: " . $self->{connection} ) if $self->{serial}->{'DEBUG'};
	$self->{log}->save('d', "command: $command") if $self->{serial}->{'DEBUG'};
	$self->{log}->save('d', "type connection: $self->{serial}->{connection}") if $self->{serial}->{'DEBUG'};

	$REQUEST = $command . $ETX;

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

	return $readline;
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

  sub clean {
	my ($raw) = @_;
	$raw =~ s/[^[:print:]]+//g;
	$raw =~ s/\s+//g;
	return $raw;
  }

  sub get_status {
	my ($self, $type, $data) = @_;
	my @bin = split //, sprintf("%b", hex($data));
	$self->{log}->save('d', "binary: ". join("|", @bin)) if $self->{serial}->{'DEBUG'};
	#return $bin[3] if $type eq 'zero';
	#return $bin[5] if $type eq 'stab';
	return $bin[6] if $type eq 'zero';
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
