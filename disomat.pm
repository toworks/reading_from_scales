package disomat;{ 
use strict;
  use warnings;
  use utf8;
  use lib 'libs';
  use parent "serial";
  use Data::Dumper;

  my $STX = pack "c1", 0x02;
  my $ETX = pack "c1", 0x03;
  my $DLE = pack "c1", 0x10;

  sub read {
	my($self,) = @_;
	#print Dumper($self);
	$self->{STX} = pack "c1", 0x02;
	print $self->{STX}, "\n";
	print $STX, "\n";
	
	my ($count_in, $string_in);

	eval{ $string_in = $self->{fh}->input || die print STDERR "$!"; };
	if(@$) { print "@$"};

	my $message = $STX."00#TK#".$DLE.$ETX.hash_bcc("00#TK#".$DLE.$ETX);
	print unpack "H*", $message;
#	$message = pack "H*", "0230302354532330230317"; #02 30 30 23 54 53 23 30 23 03 17"

	print "\n send | $message\n\n";
	$string_in = $self->{fh}->write($message) || die print STDERR "$!";
	print $string_in, "-\n";
	#select undef,undef,undef, 2000; #200 millisecond
	eval{ ($count_in, $string_in) = $self->{fh}->read(100) || die print STDERR "$!"; };
	if(@$) { print "@$"};
	print $count_in|| 0, " | | ", $string_in, "\n";
  }

  sub hash_bcc {
	my ($in) = shift;
	my @array = split('', $in);
#	print Dumper(@array);
	my $total = $array[0];
	for ( my $i=1; $i <= $#array ; $i++) {
		$total = chr(ord($total) ^ ord($array[$i]));
#		print $total, " | $i\n";
	}
	return $total;
  }

}
1;
