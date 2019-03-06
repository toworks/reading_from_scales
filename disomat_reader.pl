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
 use disomat;
 use _sql;

# my $DEBUG: shared;
# my %TASKS: shared;
# my $task_count: shared;
 
 $| = 1;  # make unbuffered

 my $log = LOG->new();
 my $conf = configuration->new($log);

 my $DEBUG = $conf->get('app')->{'debug'};
 
 $SIG{'TERM'} = $SIG{'HUP'} = $SIG{'INT'} = sub {
                      local $SIG{'TERM'} = 'IGNORE';
#						$log->save('d', "SIGNAL TERM | HUP | INT | $$");
					  $log->save('i', "stop app");
                      kill TERM => -$$;
 };

 # execute
 threads->new(\&execute, $$, $conf, $log);

 # main loop
 {
   $log->save('i', "start app");

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
    my($id, $conf, $log) = @_;
    $log->save('i', "start thread pid $id");

	my $type = $conf->get('app')->{connection};
	
	my $reader = disomat->new($log);
	$reader->set('DEBUG' => $DEBUG);
	if ( $type =~ /serial/ ) {
		$reader->set('comport' => $conf->get('serial')->{comport});
		$reader->set('baud' => $conf->get('serial')->{baud});
		$reader->set('parity' => $conf->get('serial')->{parity});
		$reader->set('databits' => $conf->get('serial')->{databits});
		$reader->set('stopbits' => $conf->get('serial')->{stopbits});
	} else {
		$reader->set('host' => $conf->get($type)->{host});
		$reader->set('port' => $conf->get($type)->{port});
		$reader->set('protocol' => $conf->get($type)->{protocol});
	}
	$reader->set('connection' => $conf->get('app')->{connection});

	# mssql create object
	my $sql = _sql->new($log);
	$sql->set('DEBUG' => $DEBUG);
	$sql->set('type' => $conf->get('sql')->{type});
	$sql->set_con(	$conf->get('sql')->{'driver'},
					$conf->get('sql')->{'host'},
					$conf->get('sql')->{'database'}	);
	$sql->set('table' => $conf->get('sql')->{'table'});

	while (1) {
		
		my ($id_scale, $weight, $status);
		
		$reader->read();

		foreach my $measure ( keys %{$conf->get('measuring')} ) {
			if ( $measure =~ /id_scale/ ) {
				print "$measure: ", $conf->get('measuring')->{$measure}, "\n";
				$id_scale = $conf->get('measuring')->{$measure};
			}
			if ( $measure =~ /in/ ) {
				foreach my $type ( keys %{$conf->get('measuring')->{$measure}} ) {
					my $bit = $conf->get('measuring')->{$measure}->{$type}->{bit} - 1;
					if ( $type =~ /weight/ ) {
						print "$type: ", $reader->get('measuring')->{$measure}[$bit], "\n";
						$weight = $reader->get('measuring')->{$measure}[$bit];
					}
				}
			}
		}

		$sql->write_weight( ($id_scale, $status, $weight) );

        print "cycle: ",$conf->get('app')->{'cycle'}, "\n" if $DEBUG;
        select undef, undef, undef, $conf->get('app')->{'cycle'} || 10;
	}
 }


