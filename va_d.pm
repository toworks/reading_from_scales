package va_d;{
  use strict;
  use warnings;
  use utf8;
  use lib 'libs';
  use parent "serial";
  use Data::Dumper;

#   протокол: ASCII
#   информация: none
#   контроллер: 20ВА-Д-2-1 WWS

  my $STX = pack "c1", 0x02;
  my $ETX = pack "c1", 0x03;
  my $REQUEST;

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
####
$readline = '2397;05/07/23;14:48:39;       1;��8855��;;��� "������";;��� "����";;���� ��������;;     240;²��  1             70kg;²��  2            170kg;;;;;;;;;;;;;:;;;;';
####
    $self->{log}->save('d', "answer: $readline") if $self->get('DEBUG');

    return $self->processing($readline);
  }

  sub processing {
    my ($self, $raw) = @_;
    my $weight;

    # message: 2397;05/07/23;14:48:39;       1;��8855��;;��� "������";;��� "����";;���� ��������;;     240;²��  1             70kg;²��  2            170kg;;;;;;;;;;;;;:;;;;
    # get weight
    my @raw_array = split(/;/, $raw);
    @raw_array[12] =~ s/\s+//g;
    print Dumper(@raw_array);

    $weight = @raw_array[12];

    $weight = $weight * $self->get('scale')->{coefficient} if defined($self->get('scale')->{coefficient});
    
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

    my ($socket, $response);

    eval {
        $socket = new IO::Socket::INET (
        PeerHost   => $self->{serial}->{host},
        PeerPort   => $self->{serial}->{port},
        Proto      => $self->{serial}->{protocol},
        Timeout    => 5,
#       Blocking => 0,
        ) || die "$!";
    };
    if($@) {
        $self->{log}->save("e", "$@"); 
        return;
    };

    eval {
        my $size = $socket->send($message);
        print "sent data of length $size\n" if $self->{serial}->{'DEBUG'};
    };
    if($@) { $self->{log}->save("e", "$@") };

    # notify server that request has been sent
    if( defined($self->get('scale')->{command}) || length($self->get('scale')->{command}) ) {
        shutdown($socket, 1);
    }

    use IO::Select;

    my $select = new IO::Select();
    $select->add($socket);
    my @socket = $select->can_read(1);
    if (@socket == 1) {
        $socket->recv($response, 1024);
        print "received response: $response\n" if $self->{serial}->{'DEBUG'};
    }
    $socket->close();

    return $response || "";
  }
}
1;
