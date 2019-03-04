package disomat;{ 
use strict;
  use warnings;
  use utf8;
  use lib 'libs';
  use parent "serial";
  use Data::Dumper;

#	протокол: SCHENCK Poll Protocol (DDP 8785)
#	информация: bvh2141gb.pdf
#	контроллер: DISOMAT B plus

  my $STX = pack "c1", 0x02;
  my $ETX = pack "c1", 0x03;
  my $DLE = pack "c1", 0x10;
  my $REQUEST = "00#TK#";

  sub read {
	my($self,) = @_;

	my ($count, $readline);

	$self->connect() if $self->get('error') == 1;
		
	#eval{ $readline = $self->{fh}->input || die "$!"; };
	#if($@) { $self->{log}->save("e", "$@") };

	my $message = $STX.$REQUEST.$DLE.$ETX.hash_bcc($REQUEST.$DLE.$ETX);
	
	$self->{log}->save('d', "request: $message") if $self->{serial}->{'DEBUG'};
	$self->{log}->save('d', "request as hex: " . unpack "H*", $message) if $self->{serial}->{'DEBUG'};

	eval{ $readline = $self->{fh}->write($message) || die "$!"; };
	if($@) { $self->{log}->save("e", "$@") };

	$self->{log}->save('d', "request count: $readline") if $self->{serial}->{'DEBUG'};
	eval{ $readline = $self->{fh}->read(255) || die "$!"; };
	if($@) { $self->{log}->save("e", "$@") };
	$self->{log}->save('d', "answer: $readline") if $self->{serial}->{'DEBUG'};
	return $readline;
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
