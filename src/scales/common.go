package scales

import (
  "fmt"
  "net"
//  "strings"
//  "time"
//  "regexp"

  "reading_from_scales/src/config"
  db "reading_from_scales/src/database"
)

type Config struct {
  *config.Scales
  ch_message chan string
  connTCP *net.TCPConn
  connUDP *net.UDPConn
  ch_db_message chan db.Kep_analytics_weight
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

func New(c *config.Scales, e bool, lv string, ch_message chan string, ch_db_message chan db.Kep_analytics_weight) *Config {
  DEBUG.enable = e
  DEBUG.level = lv

  nc := Config{c, ch_message, nil, nil, ch_db_message}

  if DEBUG.enable {
    nc.ch_message <- fmt.Sprintf("d|:|%s: config: %#v", mod_name, c)
  }

  return &nc
}

func (c *Config) Run() {

  go func () {
    if c.Connection == "network" {
        for {
            if err := c.Network_connect(); err == nil {
                if c.Command != "" {
                    c.Network_send()
                } else {
                    c.Network_receive()
                }
            }
        }
    }
  }()
}
