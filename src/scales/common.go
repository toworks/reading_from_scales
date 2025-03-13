package scales

import (
  "fmt"
  "net"
//  "strings"
//  "time"
//  "regexp"

  "reading_from_scales/src/config"
)

type Config struct {
  *config.Scales
  ch_message chan string
  connTCP *net.TCPConn
  connUDP *net.UDPConn
}

type _debug struct {
  enable bool
  level string
}

const TimeFormat string = "2006-01-02 15:04:05.000"

var (
  DEBUG = &_debug{}
  mod_name = "scales"
)

func New(c *config.Scales, e bool, lv string, ch_message chan string) *Config {
  DEBUG.enable = e
  DEBUG.level = lv

  nc := Config{c, ch_message, nil, nil}

  if DEBUG.enable {
    nc.ch_message <- fmt.Sprintf("d|:|%s: config: %#v", mod_name, c)
  }

  return &nc
}

func (c *Config) Run() {

  go func () {
	if c.Connection == "network" {
		c.Connect()
		if c.Command != "" {
			c.Write()
		} else {
			c.Read()
		}
	}
  }()
/*
  err := Connect(nc, ch_db_message)
  
  if err != nil {
	ch_db_message <- fmt.Sprintf("e|:|%s: connect: %s\n", mod_name, err.Error())
  }
*/
}

/*
func CreateConnect(c Config, ch_db_message chan string) error {
  var err error
  if DB != nil {
      err = DB.Ping()
      if err == nil {
        if DEBUG.enable {
            ch_db_message <- fmt.Sprintf("d|:|%s: CreateConnect: connection exists", mod_name)
        }
        return err
      }
  }

  DB, err = sql.Open("mssql", connection_string)
  if err != nil {
    return err
  }
  if DEBUG.enable {
    ch_db_message <- fmt.Sprintf("d|:|%s: connection host: %s  port: %s  database: %s", mod_name, c.Database.Host, c.Database.Port, c.Database.Database)
  }
  return err
}

func (c Config) Run(ch_db chan string, ch_db_message chan string) {
  go func() {
        for {
            select {
                case m := <-ch_db:
						if DEBUG.enable {
							ch_db_message <- fmt.Sprintf("d|:|%s: recived message: '%s'", "d", mod_name, m)
						}
						if m != "" {
							values := get_array_values(m, ch_db_message)
							if values[0] == "ladles_identification" {
								err := save_ladles_identification(values, ch_db_message)
								if err != nil {
									ch_db_message <- fmt.Sprintf("e|:|%s", err.Error())
								}
								if c.Database.Old_database_write_enable {
									err := save_trafic(values, ch_db_message)
									if err != nil {
										ch_db_message <- fmt.Sprintf("e|:|%s", err.Error())
									}
								}
							} else if values[0] == "input_triggering" {
								err := save_input_triggering(values, ch_db_message)
								if err != nil {
									ch_db_message <- fmt.Sprintf("e|:|%s", err.Error())
								}
								if c.Database.Old_database_write_enable {
									err := save_alarm(values, ch_db_message)
									if err != nil {
										ch_db_message <- fmt.Sprintf("e|:|%s", err.Error())
									}
								}
							}
						} else {
							ch_db_message <- fmt.Sprintf("e|:|%s: values is empty", mod_name)
						}
            }
        }
  }()
}

func get_array_values(message string, ch_db_message chan string) []string {
  values := strings.Split(message, "|:|")
  if DEBUG.enable {
    ch_db_message <- fmt.Sprintf("d|:|%s: get array values: %#v", mod_name, values)
  }
  return values
}

func save_ladles_identification(values []string, ch_db_message chan string) error {
  var query string

  if DEBUG.enable {
    ch_db_message <- fmt.Sprintf("d|:|%s: get array values: %#v", mod_name, values)
  }

  _table := values[0]
  _timestamp := values[1]
  _point := values[2]
  _ip := values[3]
  _bucket := values[4]
  _tag := values[5]
  _serial_port := values[6]

  query = fmt.Sprintf("insert into [%s] (timestamp, point, ip, bucket, tag, serial_port) values(N'%s', %s, N'%s', %s, %s, %s)",
                    _table, _timestamp, _point, _ip, _bucket, _tag, _serial_port)

  if DEBUG.enable {
	ch_db_message <- fmt.Sprintf("d|:|%s: query: %#v", mod_name, query)
  }

  t1 := time.Now()
  _, err := DB.Exec(query)
  t2 := time.Now()
  if DEBUG.enable {
      ch_db_message <- fmt.Sprintf("d|:|%s: execute time: %s", mod_name, t2.Sub(t1))
  }
  if err != nil {
      m := fmt.Sprintf("%s: execution failed: %s  query: %s", mod_name, err.Error(), query)
      if DEBUG.enable {
          ch_db_message <- fmt.Sprintf("d|:|%s", m)
      }
      return fmt.Errorf("%s", m)
  }
  return nil
}

func save_input_triggering(values []string, ch_db_message chan string) error {
  var query string

  if DEBUG.enable {
    ch_db_message <- fmt.Sprintf("d|:|%s: get array values: %#v", mod_name, values)
  }

  _table := values[0]
  _timestamp := values[1]
  _point := values[2]
  _ip := values[3]
  _name := values[4]
  _state := values[5]

  query = fmt.Sprintf("insert into [%s] (timestamp, point, ip, name, state) values(N'%s', %s, N'%s', N'%s', %s)",
                    _table, _timestamp, _point, _ip, _name, _state)

  if DEBUG.enable {
	ch_db_message <- fmt.Sprintf("d|:|%s: query: %#v", mod_name, query)
  }

  t1 := time.Now()
  _, err := DB.Exec(query)
  t2 := time.Now()
  if DEBUG.enable {
      ch_db_message <- fmt.Sprintf("d|:|%s: execute time: %s", mod_name, t2.Sub(t1))
  }
  if err != nil {
      m := fmt.Sprintf("%s: execution failed: %s  query: %s", mod_name, err.Error(), query)
      if DEBUG.enable {
          ch_db_message <- fmt.Sprintf("d|:|%s", m)
      }
      return fmt.Errorf("%s", m)
  }
  return nil
}

func save_trafic(values []string, ch_db_message chan string) error {
  var query string

  if DEBUG.enable {
    ch_db_message <- fmt.Sprintf("d|:|%s: get array values: %#v", mod_name, values)
  }

  _table := "kovsh_trafic.dbo.trafic"
  _timestamp := values[1]
  _point := values[2]
  _bucket := values[4]
  _tag := values[5]
  _serial_port := values[6]

  query = fmt.Sprintf("insert into %s (dt, tag, rf, point, dir, sdt) values(N'%s', %s%s, %s, %s, %d, N'%s')",
                    _table, _timestamp, _bucket, _tag, _serial_port, _point, 0, time.Now().Format(TimeFormat))

  if DEBUG.enable {
	ch_db_message <- fmt.Sprintf("d|:|%s: query: %#v", mod_name, query)
  }

  t1 := time.Now()
  _, err := DB.Exec(query)
  t2 := time.Now()
  if DEBUG.enable {
      ch_db_message <- fmt.Sprintf("d|:|%s: execute time: %s", mod_name, t2.Sub(t1))
  }
  if err != nil {
      m := fmt.Sprintf("%s: execution failed: %s  query: %s", mod_name, err.Error(), query)
      if DEBUG.enable {
          ch_db_message <- fmt.Sprintf("d|:|%s", m)
      }
      return fmt.Errorf("%s", m)
  }
  return nil
}

func save_alarm(values []string, ch_db_message chan string) error {
  var query string

  if DEBUG.enable {
    ch_db_message <- fmt.Sprintf("d|:|%s: get array values: %#v", mod_name, values)
  }

  _table := "kovsh_trafic.dbo.alarm"
  _timestamp := values[1]
  _point := values[2]
  _name := strings.Join(regexp.MustCompile("[0-9]+").FindAllString(values[4], -1), "")
  _state := values[5]

  query = fmt.Sprintf("insert into %s (dt, point, alarm, datchik, sdt) values(N'%s', %s, %s, %s, N'%s')",
                    _table, _timestamp, _point, _state, _name, time.Now().Format(TimeFormat))

  if DEBUG.enable {
	ch_db_message <- fmt.Sprintf("d|:|%s: query: %#v", mod_name, query)
  }

  t1 := time.Now()
  _, err := DB.Exec(query)
  t2 := time.Now()
  if DEBUG.enable {
      ch_db_message <- fmt.Sprintf("d|:|%s: execute time: %s", mod_name, t2.Sub(t1))
  }
  if err != nil {
      m := fmt.Sprintf("%s: execution failed: %s  query: %s", mod_name, err.Error(), query)
      if DEBUG.enable {
          ch_db_message <- fmt.Sprintf("d|:|%s", m)
      }
      return fmt.Errorf("%s", m)
  }
  return nil
}
*/