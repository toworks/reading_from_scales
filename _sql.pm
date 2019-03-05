package _sql;{
  use strict;
  use warnings;
  use utf8;
  use lib 'libs';
  #use parent -norequire, 'sql';
  use parent "sql";
  use DBI qw(:sql_types);
  use Data::Dumper;

  sub write_weight {
    my($self, @values) = @_;
    my($sth, $ref, $query);

    $self->conn() if ( $self->{sql}->{error} == 1 or ! $self->{sql}->{dbh}->ping );

	$query = "SET TRANSACTION ISOLATION LEVEL SERIALIZABLE ";
	$query .= "MERGE [$self->{sql}->{database}]..$self->{sql}->{table} AS trg ";
    $query .= "USING (SELECT ? ID_Scales, ? Weight_OK, ? Weight) AS src ";
    $query .= "    ON src.ID_Scales = trg.ID_Scales ";
    $query .= "WHEN MATCHED THEN UPDATE ";
    $query .= "    SET Weight_OK = src.Weight_OK, ";
	$query .= "    	   Weight    = src.Weight ";
    $query .= "WHEN NOT MATCHED THEN  ";
    $query .= "    INSERT (ID_Scales, Weight_OK, Weight)  ";
    $query .= "    VALUES (?, ?, ?); ";

	# transfer 3 parametera in query as 6
	push @values, @values;

	$self->{log}->save('d', "values: ". Dumper(@values)) if $self->{sql}->{'DEBUG'};
	$self->{log}->save('d', "query: ". $query) if $self->{sql}->{'DEBUG'};

    eval{ $self->{sql}->{dbh}->{RaiseError} = 1;
				$self->{sql}->{dbh}->{AutoCommit} = 0;
				$sth = $self->{sql}->{dbh}->prepare_cached($query) || die "$self->{sql}->{dbh}->errstr";
				$sth->execute(@values) || die "$DBI::errstr";
				$self->{sql}->{dbh}->{AutoCommit} = 1;
    };
    if ($@) {   $self->set('error' => 1);
                $self->{log}->save('e', "$@");
    };
 }
}
1;
