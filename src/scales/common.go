package scales

import (
	"fmt"
	"net"

	//  "strings"
	"regexp"
	"strconv"
	"time"

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

const (
	TimeFormat string = "2006-01-02 15:04:05.000"
	/* set timeout read/write 10 sec */
	read_write_timeout = 10000

	/* set control characters */
	STX = 0x02
	ETX = 0x03
	DLE = 0x10
)

var (
	DEBUG           = &_debug{}
	mod_name        = "scales"
	TimeFormatArray = []string{"2006-01-02 15:04:05.000",
		"06-01-02 15:04:05",
		"02.01.06 15:04:05",
		"01.02.06 15:04:05",
		"02.01.06 15:04",
		"01.02.06 15:04"}
)

func New(c *config.Scale, e bool, lv string, ch_message chan string, ch_db_message chan db.Kep_analytics_weight) *Config {
	DEBUG.enable = e
	DEBUG.level = lv

	var ncs string

	if c.Connection == "network" {
		ncs = c.Network.Host + ":" + fmt.Sprintf("%d", c.Network.Port)
	}

	nc := Config{c, ch_message, nil, ncs, ch_db_message}

	if DEBUG.enable {
		nc.ch_message <- fmt.Sprintf("d|:|%s: config: %#v", mod_name, c)
	}

	return &nc
}

func (c *Config) Run() {
	if regexp.MustCompile(`(?is)^network$`).MatchString(c.Connection) {
		go func() {
			err := fmt.Errorf("empty")

			c.ch_message <- fmt.Sprintf("i|:|%s: scale id: %d  use local timestamp: %t", mod_name, c.Id_scale, c.Local_timestamp)

			if c.Command != "" {
				if c.Read_cycle > 1000*120 || c.Read_cycle <= 0 {
					c.Read_cycle = 1000
				}

				timer := time.NewTicker(time.Duration(c.Read_cycle) * time.Millisecond)
				for _ = range timer.C {
					if err != nil {
						err = c.Network_connect()
						if err != nil {
							continue
						}
					}
					err = c.Network_send()
					if err != nil {
						c._connect.Close()
					}
					err = c.Network_receive()
					if err != nil {
						c._connect.Close()
					}
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
					if err != nil {
						c._connect.Close()
					}
				}
			}
		}()
	} else {
		c.ch_message <- fmt.Sprintf("w|:|%s: connection type: '%s' not supported", mod_name, c.Connection)
	}
}

func (c *Config) check_disabled_parameter(match string) bool {
	var pattern string

	if c.Disabled_parameters != "" {
		pattern = "(?is)" + c.Disabled_parameters
	} else {
		pattern = "(?is)^!" + match + "$"
	}
	res := regexp.MustCompile(pattern).MatchString(match)
	if DEBUG.enable {
		c.ch_message <- fmt.Sprintf("d|:|%s: disabled parameters patern: %s  match: %s  status: %v", mod_name, pattern, match, res)
	}
	return res
}

func (c *Config) get_datetime(timestamp string) string {
	var dt time.Time
	var err error
	if !c.Local_timestamp {
		for _, time_format := range TimeFormatArray {
			dt, err = time.Parse(time_format, timestamp)
			if err != nil {
				c.ch_message <- fmt.Sprintf("w|:|%s: time format: %s", mod_name, err.Error())
			} else {
				return dt.Format(TimeFormat)
			}
		}
	}
	if (err != nil && !c.Local_timestamp) || c.Local_timestamp {
		local_timestamp := time.Now().Format(TimeFormat)
		if DEBUG.enable {
			c.ch_message <- fmt.Sprintf("d|:|%s: timestamp remote: '%s'  local: %#v", mod_name, timestamp, local_timestamp)
		}
		return local_timestamp
	}
	return dt.Format(TimeFormat)
}

func (c *Config) get_value(value string) string {
	if f, err := strconv.ParseFloat(value, 64); err == nil {
		value = fmt.Sprintf("%d", int(f*c.Coefficient))
	}
	return value
}
