package _sql;{
  use strict;
  use warnings;
  use utf8;
  use lib 'libs';
  #use parent -norequire, 'sql';
  use parent "sql";
  use Data::Dumper;

  sub write_weight {
    my($self, @values) = @_;
    my($sth, $ref, $query);

    $self->conn() if ( $self->{sql}->{error} == 1 or ! $self->{sql}->{dbh}->ping );

	$query = "insert into [$self->{sql}->{database}]..$self->{sql}->{table} ";
	$query .= "(ID_Scales, Weight_OK, Weight) ";
	$query .= "values( ?, ?, ?) ";


	$query = "SET TRANSACTION ISOLATION LEVEL SERIALIZABLE ";
	$query .= "MERGE [$self->{sql}->{database}]..$self->{sql}->{table} AS trg ";
    $query .= "USING (SELECT ? ID_Scales, ? Weight_OK, ? Weight) AS src ";
    $query .= "    ON src.ID_Scales = trg.ID_Scales ";
    $query .= "WHEN MATCHED THEN UPDATE ";
    $query .= "    SET Weight_OK = src.Weight_OK ";
	$query .= "    SET Weight    = src.Weight ";
    $query .= "WHEN NOT MATCHED THEN  ";
    $query .= "    INSERT (ID_Scales, Weight_OK, Weight)  ";
    $query .= "    VALUES (?, ?, ?); ";

	print Dumper(@values);

	$self->{log}->save('d', "query: ".$query) if $self->{sql}->{'DEBUG'};

    eval{ $self->{sql}->{dbh}->{RaiseError} = 1;
				$self->{sql}->{dbh}->{AutoCommit} = 0;
				$sth = $self->{sql}->{dbh}->prepare_cached($query) || die "$self->{sql}->{dbh}->errstr";
				$sth->bind_param(1, "$id | $status") || die "$self->{sql}->{dbh}->errstr";
				$sth->bind_param(2, $id) || die "$self->{sql}->{dbh}->errstr";
				$sth->execute() || die "$self->{sql}->{dbh}->errstr";
				$self->{sql}->{dbh}->{AutoCommit} = 1;
    };
    if ($@) {   $self->set('error' => 1);
                $self->{log}->save('e', "$@");
    };

	$self->{log}->save('d', "sql get_task end") if $self->{sql}->{'DEBUG'};

    unless($@) {
        eval{
                my $count = 0;
                while ($ref = $sth->fetchrow_hashref()) {
                    #print Dumper($ref), "\n";
                    $values[$count] = $ref;
                    $count++;
                }
        }
    }
	$self->{log}->save('d', "sql get_task while data end") if $self->{sql}->{'DEBUG'};
    eval{ $sth->finish() || die "$self->{sql}->{dbh}->errstr"; };
    if ($@) {   $self->set('error' => 1);
                $self->{log}->save('e', "$@");
				$self->{log}->save('d', "$query");
    };
=cut
  }

 sub response {
    my($self, $id, $status) = @_;
    my($sth, $ref, $query);

    $self->conn() if ( $self->{sql}->{error} == 1 or ! $self->{sql}->{dbh}->ping );

    $query  = "update [$self->{sql}->{database}]..$self->{sql}->{table} ";
    $query .= "set status = ? ";
	$query .= ", dt_end = getdate() ";
    $query .= "where id = ? ";

	my $count = 0;

    LOOP: while (1) {
		eval{	$self->{sql}->{dbh}->{RaiseError} = 1;
				$self->{sql}->{dbh}->{AutoCommit} = 0;
				$sth = $self->{sql}->{dbh}->prepare_cached($query) || die "$self->{sql}->{dbh}->errstr";
				$sth->bind_param(1, "$id | $status") || die "$self->{sql}->{dbh}->errstr";
				$sth->bind_param(2, $id) || die "$self->{sql}->{dbh}->errstr";
				$sth->execute() || die "$self->{sql}->{dbh}->errstr";
				$self->{sql}->{dbh}->{AutoCommit} = 1;
		};
        if ( $@ and $count <= 10 ) {
            if("$self->{sql}->{dbh}->errstr" =~ /SQL-40001/) { # deadlock
                $self->{log}->save('e', "last: ". "$self->{sql}->{dbh}->errstr");
                $self->{log}->save('d', "$query");
                next LOOP;
            }
        }
        last;
    }
    if ($@) {
	    $self->set('error' => 1);
        $self->{log}->save('e', "$@");
		$self->{log}->save('d', "$query");
    }
  }

}
1;
