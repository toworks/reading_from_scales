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
 use cache;
 use _sql;

# my $DEBUG: shared;
# my %TASKS: shared;
# my $task_count: shared;
 
 $| = 1;  # make unbuffered

 my $VERSION = "0.1 (20200519)";
 my $log = LOG->new();
 my $conf = configuration->new($log);

 $log->save('i', "program version: ".$VERSION);

 my $DEBUG = $conf->get('app')->{'debug'};

 $SIG{'TERM'} = $SIG{'HUP'} = $SIG{'INT'} = sub {
                      local $SIG{'TERM'} = 'IGNORE';
#						$log->save('d', "SIGNAL TERM | HUP | INT | $$");
					  $log->save('i', "program stopped");
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

	my $cache = cache->new($log, $log->get_name().'.cache.yml');

	my $connection_type = $conf->{'connection'};

	my $reader = $scale_type->new($log);
	$reader->set('DEBUG' => $DEBUG);
	$reader->set('scale' => $conf->{'scale'});
	$reader->set('measuring' => $conf->{'measuring'});
	$reader->set('cache' => $cache);
	if ( $connection_type =~ /serial/ ) {
		$reader->set('comport' => $conf->{$connection_type}->{comport});
		$reader->set('baud' => $conf->{$connection_type}->{baud});
		$reader->set('parity' => $conf->{$connection_type}->{parity});
		$reader->set('databits' => $conf->{$connection_type}->{databits});
		$reader->set('stopbits' => $conf->{$connection_type}->{stopbits});
	} else {
		$reader->set('host' => $conf->{$connection_type}->{host});
		$reader->set('port' => $conf->{$connection_type}->{port});
		$reader->set('protocol' => $conf->{$connection_type}->{protocol});
	}
	$reader->set('connection' => $connection_type);

	# mssql create object
	my $sql = _sql->new($log);
	$sql->set('DEBUG' => $DEBUG);
	$sql->set('type' => $conf->{'sql'}->{type});
	$sql->set_con(	$conf->{'sql'}->{'driver'},
					$conf->{'sql'}->{'host'},
					$conf->{'sql'}->{'database'}	);
	$sql->set('table' => $conf->{'sql'}->{'table'});

	while (1) {
		
		my $status = 1;
		my $weight = $reader->read();

		$log->save('i', $conf->{'measuring'}->{id_scale}. ", " .
						strftime("%Y-%m-%d %H:%M:%S", localtime time) .
						" $status = 1, $weight" ) if defined($weight) and (ref $weight ne 'ARRAY') and $DEBUG;
		$log->save('i', $conf->{'measuring'}->{id_scale}. ", " .
						strftime("%Y-%m-%d %H:%M:%S", localtime time) .
						" $status = 1, weight: ". join(" | ", @{$weight}) )  if defined($weight) and (ref $weight eq 'ARRAY') and $DEBUG;
		print $conf->{'measuring'}->{id_scale}. ", " .
						strftime("%Y-%m-%d %H:%M:%S", localtime time) .

						" $status = 1, $weight","\n" if defined($weight) and (ref $weight ne 'ARRAY') and $DEBUG;
		print $conf->{'measuring'}->{id_scale}. ", " .
						strftime("%Y-%m-%d %H:%M:%S", localtime time) .
						" $status = 1, weight: ", join(" | ", @{$weight}), "\n" if defined($weight) and (ref $weight eq 'ARRAY') and $DEBUG;

		$sql->write_weight( ($conf->{'measuring'}->{id_scale}, strftime("%Y-%m-%d %H:%M:%S", localtime time), $status, $weight) ) if defined($weight);

        print "cycle: ",$conf->{'cycle'}, "\n" if $DEBUG;
        select undef, undef, undef, $conf->{'cycle'} || 10;
	}
 }



