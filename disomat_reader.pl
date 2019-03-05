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
# use serial;
 use disomat;
# use _sql;

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



	my $serial = disomat->new($log);
	 
	$serial->set('DEBUG' => $DEBUG);
	$serial->set('comport' => $conf->get('serial')->{comport});
	$serial->set('baud' => $conf->get('serial')->{baud});
	$serial->set('parity' => $conf->get('serial')->{parity});
	$serial->set('databits' => $conf->get('serial')->{databits});
	$serial->set('stopbits' => $conf->get('serial')->{stopbits});

=comm
	
	# mssql create object
	my $sql = sql->new($log);
	$sql->set('type' => $conf->get_conf('sql')->{type});
	$sql->set_con($conf->get_conf('sql')->{'host'}, $conf->get_conf('sql')->{'database'});
	$sql->set('table' => $conf->get_conf('sql')->{'table'});
	$sql->debug($DEBUG);
=cut
NEXT:
	while (1) {
#		next NEXT if ( $values eq 'error' ); 

#	    $log->save('i', "thread $id");
#		$log->save('i', "CYCLE $conf->{cycle}->{read_time}");
#		$mssql->save(@values);
#		splice(@values);
#		$sql->save($values->{$type});
		
		my ($weight, $status);
		
		$serial->read();

		foreach my $measure ( keys %{$conf->get('measuring')} ) {
			if ( $measure =~ /in/ ) {
				foreach my $type ( keys %{$conf->get('measuring')->{$measure}} ) {
					my $bit = $conf->get('measuring')->{$measure}->{$type}->{bit} - 1;
					if ( $type =~ /weight/ ) {
						print "$type: ", $serial->get('measuring')->{$measure}[$bit], "\n";
						$weight = $serial->get('measuring')->{$measure}[$bit];
					}
				}
			}
		}

		my $start_timestamp = time;

=comm
		foreach my $data (@{$sql->get_data}) {
			#print Dumper($data);
			print "resp: ", $data->{response}, ' | type: ', $data->{type}, "\n" if $DEBUG;
			my $res;
			if ( $data->{type} eq 'start' ) {
				# type = start -> 0 - при отправке начала сообщения
				$res = $web->generate_url($data, 0);
				if ( $res eq 1 ) {
					$sql->response($data->{mid}, $res, $data->{type});
					$log->save('i', "mid: " . $data->{mid} . "  type: " . $data->{type} . "  response: " . $res) if $DEBUG;
				} else { 
					$log->save('i', "mid: " . $data->{mid} . "  type: " . $data->{type} . "  response: " . $res) if $DEBUG;
					next NEXT; # не слать 'конец' если нет 'start'
				}
				$res = '';
			}

			if ( $data->{type} eq 'end' ) {
				# type = end -> 1 - при отправке конца сообщения
				$res = $web->generate_url($data, 1);
				if ( $res eq 1 ) {
					$sql->response($data->{mid}, $res, $data->{type});
					$log->save('i', "mid: " . $data->{mid} . "  type: " . $data->{type} . "  response: " . $res) if $DEBUG;
				} else { 
					$log->save('i', "mid: " . $data->{mid} . "  type: " . $data->{type} . "  response: " . $res) if $DEBUG;
				}
				$res = '';
			}
		}
=cut
		#print $web->get, "\n";

        print "cycle: ",$conf->get('app')->{'cycle'}, "\n" if $DEBUG;
        select undef, undef, undef, $conf->get('app')->{'cycle'} || 10 if time < $start_timestamp + $conf->get('app')->{'cycle'};
		print $start_timestamp, " | ", time, "\n" if $DEBUG;
	}
 }







 
=comm
 
 
 
 

 my $queue = Thread::Queue->new();

 my @threads;
 for ( 1..$conf->get('app')->{'tasks'} ) {
	push @threads, threads->create( \&worker, $_ );
 }

    #foreach my $thread ( threads->list() ) {
	#$thread->join();
    #}
 my (@files, @dirs, $dir, $dir_old);
 $log->save("i", "start ". $log->get_name());
 &find(\&wanted, $conf->get('find')->{'directory'});
		
 my $_files = &filter(\@files);

 PAUSE: foreach my $file ( @{$_files} ) {
	if ( $task_count eq $conf->get('app')->{'tasks'} ) {
		select undef, undef, undef, $conf->get('app')->{'cycle'} || 10;
		redo PAUSE;
	}		
	$queue->enqueue( $file );
 }

 print "cycle: ",$conf->get('app')->{'cycle'}, "\n" if $DEBUG;
 $log->save("i", "stop ". $log->get_name());

 $queue->end();

 foreach my $thread ( threads->list() ) {
	$thread->join();
 }


 sub wanted {
	$dir = $_ if -d $_;
	$dir_old = '.' if ! defined($dir_old);
	if ( $dir ne $dir_old ) {
		$dir_old = $dir;
		#print $dir, " | ", $dir_old," new \n" if $DEBUG;
		-d $_ and push @dirs, $File::Find::dir;
		-f $_ and push @files, $File::Find::name;
	} else {
		$dir_old = $dir;
		#print $dir, " | ", $dir_old, " old \n" if $DEBUG;
		-d $_ and push @dirs,  $File::Find::dir;
		-f $_ and push @files, $File::Find::name;
	}
 };

 sub filter {
 	my($files) = @_;

	my @files;
	my $match = $conf->get('find')->{'match_ext'};

	foreach my $file ( sort { $a cmp $b } @{$files} ) {
		$file =~ /^(.*)\.(.*)$/;
		my $_file = $1;
		my $ext = $2;

		#print $file, "\n" if ( $ext eq $conf->get('find')->{'ext'} and ! grep { $_file.$match ~~ /$_/g } @{$files} and $DEBUG);
#		&convert($_file) if ( $ext eq $conf->get('find')->{'ext'} and ! grep { $_file.$match ~~ /$_/g } @{$files} );
		
		#insert tasks into thread queue.
		#$process_q->enqueue( $_file ) if ( $ext eq $conf->get('find')->{'ext'} and ! grep { $_file.$match ~~ /$_/g } @{$files} );
		push @files, $_file if ( $ext eq $conf->get('find')->{'ext'} and ! grep { $_file.$match ~~ /$_/g } @{$files} );
	}
	return \@files;
 }

 sub worker {
	while ( my $file = $queue -> dequeue() ) {
		print "task_count++: ", $task_count++, "\n" if $DEBUG;
		print threads->self()->tid(). ": pinging $file\n" if $DEBUG;
		my $execute = 	$conf->get('convert')->{'app'}.
						" -i $file.".$conf->get('find')->{'ext'}.
						" ".$conf->get('convert')->{'keys'}." ".
						$file.$conf->get('find')->{'match_ext'}." 2>nul";
		$log->save("d", $execute) if $DEBUG;
		system("$execute");
		print "-----------------\n" if $DEBUG;
		print "task_count--: ", $task_count--, "\n" if $DEBUG;
	}
 }

 sub locked {
	my($file) = @_;

	open our $fh, '<', $file || die "$!";

	if ( ! flock($fh, LOCK_EX|LOCK_NB) ) {
		print "file lock\n" if $DEBUG;
		$log->save("i", "file is lock: $file");
		close $fh;
		exit;
	}
	$log->save("i", "file locking: $file");
 }

=cut


