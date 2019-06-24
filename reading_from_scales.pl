#0!/usr/bin/perl

 use strict;
 use warnings;
 use utf8;
 binmode(STDOUT,':utf8');
 use open(':encoding(utf8)');
 use Data::Dumper;  
 use threads;
 use threads::shared;
 use Time::HiRes qw(time);
 use POSIX qw(strftime);
 use LWP::UserAgent;
 use lib ('libs', '.');
 use logging;
 use configuration;
 use _sql;

# my $DEBUG: shared;
# my %TASKS: shared;
# my $task_count: shared;
 
 $| = 1;  # make unbuffered

 my $log = LOG->new();
 my $conf = configuration->new($log);

 my $DEBUG = $conf->get('app')->{'debug'};

 $log->save('i', "start app");

 $SIG{'TERM'} = $SIG{'HUP'} = $SIG{'INT'} = sub {
                      local $SIG{'TERM'} = 'IGNORE';
#						$log->save('d', "SIGNAL TERM | HUP | INT | $$");
					  $log->save('i', "stop app");
                      kill TERM => -$$;
 };

 foreach my $scale (keys %{$conf->get('scales')}) {
	if ($conf->get('scales')->{$scale}->{enabled})
	{
		eval "use $scale";
		$log->save('e', $@) if ($@);
		
		# execute
		threads->new(\&execute, $$, $conf->get('scales')->{$scale}, $log, $scale);
	}
 }

 # main loop
 {
   while (threads->list()) {
#        $log->save('d', "thread main");
       sleep(1);
       if ( ! threads->list(threads::running) ) {
#            $daemon->remove_pid();
           $SIG{'TERM'} = 'DEFAULT'; # Восстановить стандартный обработчик
           kill TERM => -$$;
		   $log->save('i', "PID $$");
        }
    }
  }


 sub execute {
    my($id, $conf, $log, $scale_type) = @_;
    $log->save('i', "start thread pid $id");
	$log->save('i', "scale: ".$conf->{'type'});

	my $connection_type = $conf->{'connection'};

	my $reader = $scale_type->new($log);
	$reader->set('DEBUG' => $DEBUG);
	$reader->set('scales' => $conf->{'scales'}->{id});
	$reader->set('command' => $conf->{'scales'}->{command});
	if ( $connection_type =~ /serial/ ) {
		$reader->set('comport' => $conf->{'serial'}->{comport});
		$reader->set('baud' => $conf->{'serial'}->{baud});
		$reader->set('parity' => $conf->{'serial'}->{parity});
		$reader->set('databits' => $conf->{'serial'}->{databits});
		$reader->set('stopbits' => $conf->{'serial'}->{stopbits});
	} else {
		$reader->set('host' => $conf->{$connection_type}->{host});
		$reader->set('port' => $conf->{$connection_type}->{port});
		$reader->set('protocol' => $conf->{$connection_type}->{protocol});
	}
	$reader->set('connection' => $conf->{connection});

	# mssql create object
	my $sql = _sql->new($log);
	$sql->set('DEBUG' => $DEBUG);
	$sql->set('type' => $conf->{'sql'}->{type});
	$sql->set_con(	$conf->{'sql'}->{'driver'},
					$conf->{'sql'}->{'host'},
					$conf->{'sql'}->{'database'}	);
	$sql->set('table' => $conf->{'sql'}->{'table'});

	while (1) {
		
		my ($id_scale, $weight, $status);
		
		$reader->read();

		foreach my $measure ( keys %{$conf->{'measuring'}} ) {
			if ( $measure =~ /id_scale/ ) {
				print "$measure: ", $conf->{measuring}->{$measure}, "\n" if $DEBUG;
				$id_scale = $conf->{'measuring'}->{$measure};
			}
			if ( $measure =~ /in/ ) {
				foreach my $type ( keys %{$conf->{'measuring'}->{$measure}} ) {
					my $bit = $conf->{'measuring'}->{$measure}->{$type}->{bit} - 1;
					if ( $type =~ /weight/ ) {
						$weight = $reader->{'measuring'}->{$measure}[$bit] * $conf->{'scales'}->{coefficient} if defined($reader->{'measuring'}->{$measure}[$bit]);
						print "$type: ", $weight, "\n" if $DEBUG;
					}
				}
			}
		}

#		$sql->write_weight( ($id_scale, strftime("%Y-%m-%d %H:%M:%S", localtime time), ($status = 1), $weight) );

        print "cycle: ",$conf->{'cycle'}, "\n" if $DEBUG;
        select undef, undef, undef, $conf->{'cycle'} || 10;
	}
 }



