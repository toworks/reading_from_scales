package blanciai;{ 
  use strict;
  use warnings;
  use utf8;
  use lib 'libs';
  use parent "serial";
  use POSIX qw(strftime);
  use cache;
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
	
	# clean Ps
	$calc_params{'Ps'} = 0;

	eval {
		$command = \%{$self->{serial}->{'scale'}->{'command'}};
		$scales = \%{$self->{serial}->{'scale'}->{'alias'}};

		print Dumper($command) if $self->{serial}->{'DEBUG'};

		# testing first running
		if ( ! defined($calc_params{$command->{'netto'}}) ) { %calc_params = %{$self->{serial}->{'cache'}->{'cache'}->{'cache'}}; }

		# step 1: <status> XZ - статус весов 
		$ANSWER = $self->_read($command->{'status'});
		return if $self->{connection} =~ /serial/ and $self->get('error') == 1;
		my $zero = $self->get_status('zero', &clean($ANSWER));
#		my $stab = $self->get_status('stab', &clean($ANSWER));

		# step 2: WghtT -> <netto> YP - вес нетто
		my $_command = $command->{'netto'};
		$ANSWER = $self->_read($_command);
		$calc_params{$_command} = &clean($ANSWER);
		undef($ANSWER);

		# step 3: <cell> DP - значение ячейки (points)
		foreach my $scale ( sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
			my $_command = $command->{'cell'} . $scales->{$scale};
			$ANSWER = $self->_read($_command);
			$calc_params{$scales->{$scale}}->{ $command->{'cell'}} = &clean($ANSWER);
			undef($ANSWER);
		}

		# step 4: <coefficient_angle> DC - коэффициент калибровки угла
		if ( $zero eq 1 ) {
			foreach my $scale ( sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
				$_command = $command->{'coefficient_angle'} . $scales->{$scale};
				$ANSWER = $self->_read($_command);
				$ANSWER =~ /\s*([\d\.\,]+)\s*([\d\.\,]+)/; # get first value $1 - first  $2 - two
				$calc_params{$scales->{$scale}}->{$command->{'coefficient_angle'}} = &clean($1);
				undef($ANSWER);
			}
		}

		# step 5: pi = di*ki;
		foreach my $scale ( sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
			$calc_params{$scales->{$scale}}->{'pi'} =
							$calc_params{$scales->{$scale}}->{$command->{'cell'}} *
							$calc_params{$scales->{$scale}}->{$command->{'coefficient_angle'}};
		}

		# not save cahe if bad data: 4376899435 
		if ( $zero eq 1 and $calc_params{$scales->{1}}->{$command->{'cell'}} < 65535 ) {
			my %cache;
			# update cache
			foreach my $scale ( sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
						$self->{log}->save('d', "zero point update cache: ". $command->{'cell'} . $scales->{$scale} .": ". $calc_params{$scales->{$scale}}->{$command->{'cell'}}) if $self->{serial}->{'DEBUG'};
						$cache{$scales->{$scale}}{$command->{'cell'}} = $calc_params{$scales->{$scale}}->{$command->{'cell'}};
						$self->{log}->save('d', "zero point update cache: ". $command->{'coefficient_angle'} . $scales->{$scale} .": ". $calc_params{$scales->{$scale}}->{$command->{'coefficient_angle'}}) if $self->{serial}->{'DEBUG'};
						$cache{$scales->{$scale}}{$command->{'coefficient_angle'}} = $calc_params{$scales->{$scale}}->{$command->{'coefficient_angle'}};
						$self->{log}->save('d', "zero point update cache: zi". $scales->{$scale} .": ". $calc_params{$scales->{$scale}}->{'pi'}) if $self->{serial}->{'DEBUG'};
						$cache{$scales->{$scale}}{'zi'} = $calc_params{$scales->{$scale}}->{'pi'};
			}
			$self->{serial}->{'cache'}->set('cache' => \%cache);
			$self->{serial}->{'cache'}->set('timestamp' => strftime("%Y-%m-%d %H:%M:%S", localtime time));
			$self->{serial}->{'cache'}->save();
		}

		# step 6: При WghtT = 0 :  zi = pi;
		if ( $zero eq 1 ) {
			foreach my $scale ( sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
				$calc_params{$scales->{$scale}}->{'zi'} = $calc_params{$scales->{$scale}}->{'pi'};
			}
		}

		# step 7: При WghtT ≠ 0 : pi = pi – zi;
		if ( $zero eq 0 ) {
			foreach my $scale ( sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
				$calc_params{$scales->{$scale}}->{'pi'} = $calc_params{$scales->{$scale}}->{'pi'} -
														  $calc_params{$scales->{$scale}}->{'zi'};
			}
		}

		# step 8: Ps = pi+pi+pi+pi+pi+pi+pi+pi;
		foreach my $scale (sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
			#if ( defined($zero) and $zero ne 1 and defined($calc_params{$scales->{$scale}}->{'zi'}) ) {
				$self->{log}->save('d', "Ps p". $scales->{$scale} .": ". $calc_params{$scales->{$scale}}->{'pi'}) if $self->{serial}->{'DEBUG'};
				$calc_params{'Ps'} += $calc_params{$scales->{$scale}}->{'pi'};
			#}
		}		


#		if ( $zero eq 0 ) {
			foreach my $scale (sort {$scales->{$a} <=> $scales->{$b}} keys %{$scales} ) {
				# step 9: ki = Ps/pi;
				$calc_params{$scales->{$scale}}->{'ki'} = $calc_params{'Ps'} /
														  $calc_params{$scales->{$scale}}->{'pi'};
				# step 10: wi = WghtT/ki
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
#		}
		
		print Dumper(\%calc_params) if $self->{serial}->{'DEBUG'};
		$self->{log}->save('d', "calc_params: ". Dumper(\%calc_params)) if $self->{serial}->{'DEBUG'};

		push @weights, $weight_platform1, $weight_platform2;

		# remove 0 array variable
		splice @weights, 0, 1;
	};
	if($@) { $self->{log}->save("e", "$@") };

	$self->{log}->save('d', Dumper(@weights) ) if $self->{serial}->{'DEBUG'};
	
	return \@weights;
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
		if($@) { $self->{log}->save("e", "$@");
				 $self->set('error' => 1);
		};
		
		return if $self->get('error') == 1;
		
		$self->{log}->save('d', "request count: $readline") if $self->{serial}->{'DEBUG'};
		eval{ $readline = $self->{fh}->read(255) || die "$!"; };
		if($@) { $self->{log}->save("e", "$@");
				 $self->set('error' => 1);
		};
	} else {
		$readline = $self->net_read($REQUEST);
	}

	$readline = "" unless defined($readline);
	
	$self->{log}->save('d', "answer: $readline") if $self->{serial}->{'DEBUG'};

	return $readline;
  }

  sub clean {
	my ($raw) = @_;
	return if ! defined($raw);
	$raw =~ s/[^[:print:]]+//g;
	$raw =~ s/\s+//g;
	return $raw;
  }

  sub get_status {
	my ($self, $type, $data) = @_;
	my $ret;
	my @bin = split //, sprintf("%b", hex($data));
	if ( ! defined($bin[6]) and $type eq 'zero' ) {
		$self->{log}->save('e', "binary command 'zero'    count: ". $#bin);
		$ret = 0;
	} else {
		$self->{log}->save('d', "binary: ". join("|", @bin)) if $self->{serial}->{'DEBUG'};
		#return $bin[3] if $type eq 'zero';
		#return $bin[5] if $type eq 'stab';
		$ret = $bin[6] if $type eq 'zero';
	}
	return $ret;
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

	return $response;
  }
}
1;
