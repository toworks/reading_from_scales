package scales

import (
  "fmt"
  "net"
//  "strings"
  "time"
  "regexp"


  "reading_from_scales/src/config"
  db "reading_from_scales/src/database"
)

type Config struct {
  *config.Scale
  ch_message                chan string
  _connect                  net.Conn
  network_connection_string string
  ch_db_message             chan db.Kep_analytics_weight
}

type _debug struct {
  enable bool
  level  string
}

const TimeFormat string = "2006-01-02 15:04:05.000"
/* set timeout read/write 10 sec */
const read_write_timeout = 10000

var (
  DEBUG = &_debug{}
  mod_name = "scales"
)

func New(c *config.Scale, e bool, lv string, ch_message chan string, ch_db_message chan db.Kep_analytics_weight) *Config {
  DEBUG.enable = e
  DEBUG.level = lv

  var ncs string

  if c.Connection == "network" {
	ncs = c.Network.Host+":"+fmt.Sprintf("%d", c.Network.Port)
  }
 
  nc := Config{c, ch_message, nil, ncs, ch_db_message}

  if DEBUG.enable {
    nc.ch_message <- fmt.Sprintf("d|:|%s: config: %#v", mod_name, c)
  }

  return &nc
}

func (c *Config) Run() {
  if regexp.MustCompile(`(?is)^network$`).MatchString(c.Connection) {
	go func () {
			err := fmt.Errorf("empty")

			if c.Command != "" {
				if c.Read_cycle > 1000 * 120 || c.Read_cycle <= 0 {
					c.Read_cycle = 1000
				}

				timer := time.NewTicker(time.Duration(c.Read_cycle) * time.Millisecond)
				for _ = range timer.C {
					if err != nil {
						err = c.Network_connect()
					}
					err = c.Network_send()
					err = c.Network_receive()
				}
			} else {
				for {
					if err != nil {
						err = c.Network_connect()
						if err != nil {
							time.Sleep(time.Second * 2)
							continue
						}
					}
					err = c.Network_receive()
				}
			}
	}()
  } else {
	c.ch_message <- fmt.Sprintf("w|:|%s: connection type: '%s' not supported", mod_name, c.Connection)
  }
}
