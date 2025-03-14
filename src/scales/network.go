package scales

import (
	"fmt"
    "time"
	"strings"
	"net"
)


func (c *Config) Network_connect() error {
	var err error
	var resolveTCP *net.TCPAddr
	var resolveUDP *net.UDPAddr

  connection_string := c.Network.Host+":"+fmt.Sprintf("%d", c.Network.Port)
  c.Network.Protocol = strings.ToLower(c.Network.Protocol)

  if c.Network.Protocol == "tcp" {
	resolveTCP, err = net.ResolveTCPAddr(c.Network.Protocol, connection_string)
  } else if c.Network.Protocol == "udp" {
	resolveUDP, err = net.ResolveUDPAddr(c.Network.Protocol, connection_string)
  } else {
	err = fmt.Errorf("unsupported protocol: ", c.Network.Protocol)
  }
  if err != nil {
	c.ch_message <- fmt.Sprintf("e|:|%s: resolve failed: %s  error: %s", mod_name, connection_string, err.Error())
	return err
  }

  t1 := time.Now()
  if c.Network.Protocol == "tcp" {
	c.connTCP, err = net.DialTCP(c.Network.Protocol, nil, resolveTCP)
	c.ch_message <- fmt.Sprintf("e|:|%s: connTCP: %#v", mod_name, c.connTCP)
  } else if c.Network.Protocol == "udp" {
	c.connUDP, err = net.DialUDP(c.Network.Protocol, nil, resolveUDP)
  }
  t2 := time.Now()
  if err != nil {
	c.ch_message <- fmt.Sprintf("e|:|%s: dial failed: %s  error: %s", mod_name, connection_string, err.Error())
	return err
  }
  if DEBUG.enable {
	c.ch_message <- fmt.Sprintf("d|:|%s: connect time: %s", mod_name, t2.Sub(t1))
  }
  return nil
}

//  переделать убрать/изменить цикл запроса
func (c *Config) Network_send() {
  var err error
  connection_string := c.Network.Host+":"+fmt.Sprintf("%d", c.Network.Port)
  cycle := 1000

	timer := time.NewTicker(time.Duration(cycle) * time.Millisecond)
	for _ = range timer.C {
		t1 := time.Now()
		_, err = c.connTCP.Write([]byte(c.Command))
		t2 := time.Now()
		if err != nil {
			c.ch_message <- fmt.Sprintf("e|:|%s: send failed: %s  error: %s", mod_name, connection_string, err.Error())
		}
		if DEBUG.enable {
			c.ch_message <- fmt.Sprintf("d|:|%s: send command: %s", mod_name, c.Command)
			c.ch_message <- fmt.Sprintf("d|:|%s: send command time: %s", mod_name, t2.Sub(t1))
		}
		c.Network_receive()
	}
}

func (c *Config) Network_receive() {
  var err error
  connection_string := c.Network.Host+":"+fmt.Sprintf("%d", c.Network.Port)

  reply := make([]byte, 1024)

  t1 := time.Now()
  _, err = c.connTCP.Read(reply)
  t2 := time.Now()
  if err != nil {
	c.ch_message <- fmt.Sprintf("e|:|%s: receive failed: %s  error: %s", mod_name, connection_string, err.Error())
  }
  if DEBUG.enable {
	c.ch_message <- fmt.Sprintf("d|:|%s: receive raw data: %s", mod_name, string(reply))
	c.ch_message <- fmt.Sprintf("d|:|%s: receive time: %s", mod_name, t2.Sub(t1))
  }
  
  c.Type = strings.ToLower(c.Type)

  if c.Type == "bullat" {
	c.ProcessingBullat(string(reply))
  }
}
