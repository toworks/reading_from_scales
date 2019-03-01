#!D:\bin\perl\perl\bin\perl.exe


package main;
  use strict;
  use warnings;
  use utf8;
#  binmode(STDOUT,':utf8');
#  use open(':encoding(utf8)');
  use Win32::SerialPort;
  use Data::Dumper;

  $| = 1; #flushing output

  my (%serial, %serial_port);
  $serial{comport} = "COM";
  $serial{baud} = 9600;
  $serial{parity} = "even";
  $serial{databits} = 8;
  $serial{stopbits} = 1;
  $serial{timeout} = 1500;

  my @ports = (4);
  my $m_send_weight = 0;
  my $m_send_sign = 0;


  foreach ( @ports ) {
	  eval{ $serial_port{$_} = new Win32::SerialPort($serial{comport}.$_);
			$serial_port{$_}->databits($serial{databits});
			$serial_port{$_}->baudrate($serial{baud});
			$serial_port{$_}->parity($serial{parity});
			$serial_port{$_}->stopbits($serial{stopbits});
			$serial_port{$_}->read_interval(10);
			$serial_port{$_}->read_const_time($serial{timeout});
			$serial_port{$_}->error_msg(1);
			$serial_port{$_}->user_msg(1);
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

  my $STX = pack "c1", 0x02;
  my $ETX = pack "c1", 0x03;
  my $DLE = pack "c1", 0x10;
  my $c = 0;
  
  print hash_bcc("00#TS#".$DLE.$ETX), "\n";
 #print chr(-28), "\n";
# exit;

  
  while (1) {
	foreach (@ports) {
	
		#eval{ ($count_in, $string_in) = $serial_port{$_}->read(100) || die print STDERR "$!"; };# обработка ошибки
		eval{ $string_in = $serial_port{$_}->input || die print STDERR "$!"; };
		if(@$) { print "@$"};
		
#		last unless $string_in;


		$message = $STX."00#TK#".$DLE.$ETX.hash_bcc("00#TK#".$DLE.$ETX);
		print unpack "H*", $message;
#		$message = pack "H*", "0230302354532330230317"; #02 30 30 23 54 53 23 30 23 03 17"

		print "\n send | $message\n\n";
		$string_in = $serial_port{$_}->write($message) || die print STDERR "$!";
		print $string_in, "-\n";
		#select undef,undef,undef, 2000; #200 millisecond
		eval{ ($count_in, $string_in) = $serial_port{$_}->read(100) || die print STDERR "$!"; };
		if(@$) { print "@$"};
		print $count_in|| 0, " | | ", $string_in, "\n";
	}
	print "cycle\n";
	select undef, undef, undef, 0.5; #200 millisecond
 }


sub hash_bcc {
  my ($in) = shift;
  my @array = split('', $in);
#  print Dumper(@array);
  my $total = $array[0];
  for ( my $i=1; $i <= $#array ; $i++) {
	$total = chr(ord($total) ^ ord($array[$i]));
#	print $total, " | $i\n";
 }
 return $total;
}





