#!D:\bin\perl\perl\bin\perl.exe


package main;
  use strict;
  use warnings;
  use utf8;
#  binmode(STDOUT,':utf8');
#  use open(':encoding(utf8)');
  use Win32::SerialPort;
  use Time::HiRes qw(usleep);
  use Data::Dumper;

  $| = 1; #flushing output

  my (%serial, %serial_port);
  $serial{comport} = "com";
  $serial{baud} = 9600;
  $serial{parity} = "none";
  $serial{databits} = 8;
  $serial{stopbits} = 1;
  $serial{timeout} = 100;

  my @ports = (1);
  my $rts_timing = 1;
  my $m_send_weight = 0;
  my $m_send_sign = 0;

  foreach ( @ports ) {
	  eval{ $serial_port{$_} = new Win32::SerialPort($serial{comport}.$_);
			$serial_port{$_}->databits($serial{databits});
			$serial_port{$_}->baudrate($serial{baud});
			$serial_port{$_}->parity($serial{parity});
			$serial_port{$_}->stopbits($serial{stopbits});
			$serial_port{$_}->handshake('rts');
			$serial_port{$_}->buffers(4096, 4096);
			#$serial_port{$_}->read_interval(10);
			#$serial_port{$_}->read_const_time($serial{timeout});
			$serial_port{$_}->read_interval(0);
			$serial_port{$_}->read_const_time(1000);
			$serial_port{$_}->error_msg(1);
			$serial_port{$_}->user_msg(1);
			$serial_port{$_}->datatype('raw');
			$serial_port{$_}->debug(1);
			$serial_port{$_}->rts_active(1);            # return status of ioctl call
			$serial_port{$_}->write_settings;
			print "create $serial{comport}$_\n";
		};# обработка ошибки
  }	
  
  my $message ;#@message;
  my ($count_in, $string_in);
=comm
  $message[0] = chr(154);#pack "H*", ord(0xDC);
  $message[1] = chr(1);
  $message[2] = chr(53); #567
  $message[3] = chr(54);
  $message[4] = chr(55);
  $message[5] = chr(56); #821
  $message[6] = chr(50);
  $message[7] = chr(49);
  $message[8] = chr(50);
  $message[9] = chr(255);
  $message[10] = chr(199);#pack "H*", ord(0xC3);
=cut

  my $start = pack "c1", 0x02;
  my $end = "\r";
  #my $end = pack "H*", ord(0x0D);
  
  while (1) {
	foreach (@ports) {
		ack($serial_port{$_});
		$message = "XN".$end;
		print $message."\n";
		eval{ $serial_port{$_}->write($message) || die print STDERR "$!"; };# обработка ошибки
		if($@) { print "error write: $@\n"}

#my $flowcontrol = $serial_port{$_}->handshake;    # current value (scalar)
#my @handshake_opts = $serial_port{$_}->handshake; # permitted choices (list)
#print "flowcontrol: $flowcontrol\n";
#print  join(" | ", @handshake_opts), "\n";
#		ack($serial_port{$_});
		eval{ ($count_in, $string_in) = $serial_port{$_}->read(255) || die print STDERR "$!"; };# обработка ошибки
		#eval{ $string_in = $serial_port{$_}->input || die print STDERR "$!"; };# обработка ошибки
		if($@) { print "error read: $@\n"}
		
#		last unless $string_in;		
#		print "in m_send_weight | $m_send_weight | m_send_sign | $m_send_sign | " .$string_in."\n\n";
		print "string_in | $string_in | count_in | $count_in\n";

#		$serial_port{$_}->close;
#		$serial_port{$_}->lookclear; # empty buffers
  }
  pause( 50_000 ); # because the $PortObj->read is nonblocking, we don't want to loop too tight. so pause 50ms if a read fails.
  #usleep(1000*1200); #200 millisecond
 }
 
 
 sub ack {
	my $PortObj = shift;
    $PortObj->rts_active( 0 );
    #pause( $rts_timing );
	pause();
    $PortObj->rts_active( 1 );
 }

sub pause {
    my $time = shift || 500_000; # micro seconds
    usleep( $time );
    return 1;
}


