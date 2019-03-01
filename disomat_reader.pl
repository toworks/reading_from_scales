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

 my $serial = disomat->new($log);
 
 $serial->set('DEBUG' => $DEBUG);
 $serial->set('comport' => $conf->get('serial')->{comport});
 $serial->set('baud' => $conf->get('serial')->{baud});
 $serial->set('parity' => $conf->get('serial')->{parity});
 $serial->set('databits' => $conf->get('serial')->{databits});
 $serial->set('stopbits' => $conf->get('serial')->{stopbits});

 print Dumper($serial);
 
 $serial->connect();
 $serial->read();
 
 
 
 
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


