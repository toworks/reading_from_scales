package va_d;{
  use strict;
  use warnings;
  use utf8;
  use lib 'libs';
  use parent "serial";
  use Data::Dumper;
  use constant BUFSIZE => 1024;

#   протокол: ASCII
#   информация: none
#   контроллер: 20ВА-Д-2-1 WWS

  my $STX = pack "c1", 0x02;
  my $ETX = pack "c1", 0x03;
  my $REQUEST;
  my $BUFFER_WEIGHT = 0;
  my $BUFFER_NEXT_TIMESTAMP = 0;
  my $socket;
  my $select;

  sub read {
    my ($self) = @_;

    if ( defined($self->{serial}->{connection}) ) {
        $self->{connection} = $self->{serial}->{connection};
    }

    if (defined($self->{serial}->{'scale'}->{command}) ) {
        $REQUEST = $STX . $self->{serial}->{'scale'}->{command} . $ETX;
        $self->{log}->save('d', "request: $REQUEST") if $self->get('DEBUG');
    }

    $self->{log}->save('d', "connection type: " . $self->{connection} ) if $self->get('DEBUG');
    $self->{log}->save('d', "type connection: $self->{serial}->{connection}") if $self->get('DEBUG');

    my ($count, $readline, $msg);

    if ( $self->{connection} =~ /serial/ ) {
        $self->connect() if $self->get('error') == 1;
        
        return if $self->get('error') == 1;

        #eval{ $readline = $self->{fh}->input || die "$!"; };
        #if($@) { $self->{log}->save("e", "$@") };

        if (defined($self->{serial}->{'scale'}->{command}) ) {
            eval{ $readline = $self->{fh}->write($REQUEST) || die "$!"; };
            if($@) { $self->{log}->save("e", "$@") };
        }
# serial port no code to work

#       $self->{log}->save('d', "request count: $readline") if $self->get('DEBUG');
        eval{ 
                my $s = 0;
                my $c = 0;
                while ($c == 0) {
                    $readline = $self->{fh}->read(255) || die "$!";
                    my @bytes = map { unpack('H*', $_) } ($readline =~ /(.)/g);
                    foreach my $_hex (@bytes) {
                        if ( ($_hex =~ /$STX/ and $s == 0) or $s == 1 ) {
                            $msg .= $_hex;
                            $s = 1;
                        }
                        if ( $_hex =~ /$ETX/ and $s == 1 ) {
                            $s = 0;
                            $c = 1;
                            $readline = $msg;
                            last;
                        }
                    }
                }
        };
        if($@) { $self->{log}->save("e", "$@") };
    } else {
        $readline = $self->net_read();
    }

    $self->{log}->save('d', "answer: $readline") if $self->get('DEBUG');

    my $weight = $self->processing($readline);

    $self->{log}->save('d', "last buffer next timestsmp: " . $BUFFER_NEXT_TIMESTAMP . "  buffer weight: " . $BUFFER_WEIGHT . "  weight: " . $weight) if $self->get('DEBUG');
    print '>> current timestamp: ', time, "  next timestamp: ", $BUFFER_NEXT_TIMESTAMP, "  buffer weight: ", $BUFFER_WEIGHT, "  weight: ", $weight, "\n" if $self->get('DEBUG');

    if ( defined($weight) and $weight ne 0 and time gt $BUFFER_NEXT_TIMESTAMP ) {
            $BUFFER_NEXT_TIMESTAMP = time + $self->get('scale')->{weight_memory_time};
            $BUFFER_WEIGHT = $weight;
    } else {
            $BUFFER_WEIGHT = 0 if ( (!defined($weight) or $weight eq 0) and time gt $BUFFER_NEXT_TIMESTAMP );
            $weight = $BUFFER_WEIGHT;
    }

    $self->{log}->save('d', "new buffer nex timestsmp: " . $BUFFER_NEXT_TIMESTAMP . "  buffer weight: " . $BUFFER_WEIGHT . "  weight: " . $weight) if $self->get('DEBUG');
    print '<< current timestamp: ', time, "  next timestamp: ", $BUFFER_NEXT_TIMESTAMP, "  buffer weight: ", $BUFFER_WEIGHT, "  weight: ", $weight, "\n" if $self->get('DEBUG');

    return $weight;
  }

  sub processing {
    my ($self, $raw) = @_;
    my ($weight, $weight_position);

    if ( defined $self->get('scale')->{weight_position} ) {
        $weight_position = $self->get('scale')->{weight_position};
    } else {
        $weight_position = 0;
    }

    # position 12
    # message: 2397;05/07/23;14:48:39;       1;��8855��;;��� "������";;��� "����";;���� ��������;;     240;²��  1             70kg;²��  2            170kg;;;;;;;;;;;;;:;;;;
    # position 7
    # message: 3123;17/10/23;15:13;       5;ÊÀ3694ÑÕ;;       2;   51500;    8610;   10570;   16730;   15590;;;;;;;;;;;
    # get weight
    my @raw_array = split(/;/, $raw);
    @raw_array[$weight_position] =~ s/\s+//g if defined(@raw_array[$weight_position]) and @raw_array[1] =~ /[0-9]+\/[0-9]+\/[0-9]+/;
    print Dumper(@raw_array) if $self->get('DEBUG');

    $weight = @raw_array[$weight_position] if defined(@raw_array[$weight_position]) and @raw_array[1] =~ /[0-9]+\/[0-9]+\/[0-9]+/;

    $weight = $weight * $self->get('scale')->{coefficient} if defined($self->get('scale')->{coefficient}) and defined($weight);
    
    $self->{log}->save('d', "processing weight: " . $weight ) if $self->get('DEBUG');

    return $weight;
  }

  sub net_read {
    my ($self, $message) = @_;

    use IO::Socket::INET;

    $| = 1;

    $self->{log}->save('d', "host: ".$self->{serial}->{host}.
                            " port: ".$self->{serial}->{port}.
                            " protocol: ".$self->{serial}->{protocol}) if $self->{serial}->{'DEBUG'};

    my (@socket, $response);

    eval {
        unless (defined($socket)) {
            $socket = new IO::Socket::INET (
            PeerHost   => $self->{serial}->{host},
            PeerPort   => $self->{serial}->{port},
            Proto      => $self->{serial}->{protocol},
            Timeout    => 5,
#           Blocking => 0,
            ) || die "$!";

            use IO::Select;
            $select = new IO::Select() || die "$!";
            $select->add($socket) || die "$!";
       };
    };
    if($@) {
        $self->{log}->save("e", "$@"); 
        return;
    };

    eval {
        @socket = $select->can_read(1);
    };
    if($@) {
        $self->{log}->save("e", "$@"); 
        eval { $socket->close(); };
        undef $socket;
        return;
    };

    for my $handle (@socket) {
        print STDERR "SOCKET handle ready\n" if $self->{serial}->{'DEBUG'};
        if ( sysread($handle, $response, BUFSIZE) gt 0 ) {
                ##syswrite (STDOUT, $buffer);
                $self->{log}->save('d', "raw: ". $response) if $self->{serial}->{'DEBUG'};
                print  "response: ", $response, "\n" if $self->{serial}->{'DEBUG'};
        } else {
                warn "connection closed by foreign host\n";
                $self->{log}->save('i', "connection closed by foreign host: ". 
                                            $self->{serial}->{protocol} . "//:".
                                            $self->{serial}->{host} . ":".
                                            $self->{serial}->{port});
                $self->set('error' => 1);
                eval { $socket->close(); };
                undef $select;
                return;
        }
    }

    return $response || "";

  }
}
1;
