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
    my($self, $id_scale, $timestamp, $status, $weight) = @_;
    my($sth, $ref, $query);

    $self->conn() if ( $self->{sql}->{error} == 1 or ! $self->{sql}->{dbh}->ping );

	if (ref $weight ne 'ARRAY') {
		$query  = "INSERT [$self->{sql}->{database}]..$self->{sql}->{table} (ID_Scales, DT, WeightStabilized_1, Weight_platform_1) ";
		$query .= "VALUES (?, ?, ?, ?) ";
	}

	if (ref $weight eq 'ARRAY') {
		$query  = "INSERT [$self->{sql}->{database}]..$self->{sql}->{table} (ID_Scales, DT, Weight, WeightStabilized_1, ";
		$query .= "load_sensor_1, load_sensor_2, load_sensor_3, load_sensor_4, ";
		$query .= "load_sensor_5, load_sensor_6, load_sensor_7, load_sensor_8, Weight_platform_1, Weight_platform_2) ";
		$query .= "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ";
	}

	$weight = [$weight] if (ref $weight ne 'ARRAY');
	
	my @values = ($id_scale, $timestamp, $status, @{$weight});

	$self->{log}->save('d', "values: " . join(" | ", @values)) if $self->{sql}->{'DEBUG'};
	$self->{log}->save('d', "query: ". $query) if $self->{sql}->{'DEBUG'};

	eval{ 		$self->{sql}->{dbh}->{RaiseError} = 1;
				$self->{sql}->{dbh}->{AutoCommit} = 0;
				$sth = $self->{sql}->{dbh}->prepare_cached($query) || die "$self->{sql}->{dbh}->errstr";
				$sth->execute(@values) || die "$self->{sql}->{dbh}->errstr";
				$self->{sql}->{dbh}->{AutoCommit} = 1;
	};
	if ($@) {   $self->set('error' => 1);
				$self->{log}->save('e', "$@");
	}
 }
}
1;
