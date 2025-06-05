package database

import (
  "fmt"
  //"strings"
  "time"
  "database/sql"
  "regexp"

  _ "github.com/denisenkom/go-mssqldb"

  "reading_from_scales/src/config"
)

type Config struct {
  *config.Database
  ch_message chan string
  ch_db_message chan Kep_analytics_weight
}

type _debug struct {
  enable bool
  level string
}

type Kep_analytics_weight struct {
  Id_scales string
  Timestamp string
  Lafet string
  Wagon string
  Weight string
  Weight_platform_1 string
  Weight_platform_2 string
  Weight_platform_3 string
  L_bias_weight string
  H_bias_weight string
  Weight_ok string
  Trace_sensor_1 string
  Trace_sensor_2 string
  Trace_sensor_3 string
  Trace_sensor_4 string
  Trace_sensor_5 string
  Trace_sensor_6 string
  Trace_sensor_7 string
  Trace_sensor_8 string
  Load_sensor_1 string
  Load_sensor_2 string
  Load_sensor_3 string
  Load_sensor_4 string
  Load_sensor_5 string
  Load_sensor_6 string
  Load_sensor_7 string
  Load_sensor_8 string
  Load_sensor_9 string
  Load_sensor_10 string
  Load_sensor_11 string
  Load_sensor_12 string
  Trace_sensor_9 string
  Trace_sensor_10 string
  Trace_sensor_11 string
  Trace_sensor_12 string
  Weight_stabilized_1 string
  Weight_stabilized_2 string
  Weight_stabilized_3 string
  W1 string
  W2 string
  W3 string
  W4 string
  W5 string
  W6 string
}

const TimeFormat string = "2006-01-02 15:04:05.000"

var (
  DEBUG = &_debug{}
  mod_name = "database"
  connection_string string
  DB *sql.DB
  kaw = &Kep_analytics_weight{}
)

func New(c *config.Database, e bool, lv string, ch_message chan string, ch_db_message chan Kep_analytics_weight) *Config {
  DEBUG.enable = e
  DEBUG.level = lv

  nc := Config{c, ch_message, ch_db_message}
  connection_string = fmt.Sprintf("server=%s;port=%s;user id=%s;password=%s;database=%s",
                                nc.Database.Host, nc.Database.Port, nc.Database.Username,
                                nc.Database.Password , nc.Database.Database)

  if DEBUG.enable {
    nc.ch_message <- fmt.Sprintf("d|:|%s: config: %#v", mod_name, c)
    nc.ch_message <- fmt.Sprintf("d|:|%s: connection string: %#v", mod_name, connection_string)
  }

  err := nc.CreateConnect()
  if err != nil {
	nc.ch_message <- fmt.Sprintf("e|:|%s: connect: %s\n", mod_name, err.Error())
  }

  return &nc
}

func (c *Config) CreateConnect() error {
  var err error
  if DB != nil {
      err = DB.Ping()
      if err == nil {
        if DEBUG.enable {
            c.ch_message <- fmt.Sprintf("d|:|%s: CreateConnect: connection exists", mod_name)
        }
        return err
      }
  }

  DB, err = sql.Open("mssql", connection_string)
  if err != nil {
    return err
  }
  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: connection host: %s  port: %s  database: %s", mod_name, c.Database.Host, c.Database.Port, c.Database.Database)
  }
  return err
}

func (c *Config) Run() {
  go func() {
        for {
            select {
                case kaw := <-c.ch_db_message:
						if DEBUG.enable {
							c.ch_message <- fmt.Sprintf("d|:|%s: recived message: '%#v'", mod_name, kaw)
						}
						if kaw.Id_scales != "" {
							err := c.kep_analytics_weight_save(kaw)
							if err != nil {
								c.ch_message <- fmt.Sprintf("e|:|%s: %s", mod_name, err.Error())
							}
							/*values := c.get_array_values(m)
							if values[0] == "ladles_identification" {
								err := c.save_ladles_identification(values)
								if err != nil {
									c.ch_message <- fmt.Sprintf("e|:|%s", err.Error())
								}
							} else if values[0] == "input_triggering" {
								err := c.save_input_triggering(values)
								if err != nil {
									c.ch_message <- fmt.Sprintf("e|:|%s", err.Error())
								}
							}*/
						} else {
							c.ch_message <- fmt.Sprintf("e|:|%s: values is empty", mod_name)
						}
				default:
            }
        }
  }()
}

func (c *Config) kep_analytics_weight_save(kaw Kep_analytics_weight) error {
  var query string

  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: kep_analytics_weight_save values: %#v", mod_name, kaw)
  }

  _database := regexp.MustCompile("([\\[\\]])").ReplaceAllString(c.Database.Database, "")
  _table := regexp.MustCompile("([\\[\\]])").ReplaceAllString(c.Database.Table, "")

  query = fmt.Sprintf(`insert into [%s]..[%s] ( id_scales, dt, weight,
						weight_platform_1, weight_platform_2, weight_platform_3,
						l_bias_weight, h_bias_weight,
						WeightStabilized_1, WeightStabilized_2, WeightStabilized_3,
						w1, w2, w3, w4)
						values(%s, N'%s', %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)`,
                    _database, _table,
					empty_to_null(kaw.Id_scales), empty_to_null(kaw.Timestamp), empty_to_null(kaw.Weight),
					empty_to_null(kaw.Weight_platform_1), empty_to_null(kaw.Weight_platform_2),
					empty_to_null(kaw.Weight_platform_3),
					empty_to_null(kaw.L_bias_weight), empty_to_null(kaw.H_bias_weight),
					empty_to_null(kaw.Weight_stabilized_1), empty_to_null(kaw.Weight_stabilized_2),
					empty_to_null(kaw.Weight_stabilized_3),
					empty_to_null(kaw.W1), empty_to_null(kaw.W2), empty_to_null(kaw.W3), empty_to_null(kaw.W4))

  if DEBUG.enable {
	c.ch_message <- fmt.Sprintf("d|:|%s: query: %#v", mod_name, query)
  }

  t1 := time.Now()
  _, err := DB.Exec(query)
  t2 := time.Now()
  if DEBUG.enable {
      c.ch_message <- fmt.Sprintf("d|:|%s: execute time: %s", mod_name, t2.Sub(t1))
  }
  if err != nil {
      m := fmt.Sprintf("%s: execution failed: %s  query: %s", mod_name, err.Error(), query)
      if DEBUG.enable {
          c.ch_message <- fmt.Sprintf("d|:|%s", m)
      }
      return fmt.Errorf("%s", m)
  }
  return nil
}

func empty_to_null(v string) string {
	if v == "" {
		return "NULL"
	}
	return v
}