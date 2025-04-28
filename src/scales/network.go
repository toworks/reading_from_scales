package scales

import (
    "fmt"
    "time"
    "strings"
    "regexp"
    "net"
)


func (c *Config) Network_connect() error {
  var err error

  if ! regexp.MustCompile(`(?is)^udp|tcp`).MatchString(c.Network.Protocol) {
	c.Network.Protocol = "tcp"
  }

  t1 := time.Now()
  c._connect, err = net.Dial(c.Network.Protocol, c.network_connection_string)
  t2 := time.Now()
  if err != nil {
    c.ch_message <- fmt.Sprintf("e|:|%s: dial failed: %s  error: %s", mod_name, c.network_connection_string, err.Error())
    return err
  }
  /* set timeout read/write */
  c._connect.SetDeadline(time.Now().Add(time.Second * 10))

  c.ch_message <- fmt.Sprintf("i|:|%s: connect: %s  time: %s", mod_name, c.network_connection_string, t2.Sub(t1))
  return nil
}
/*
func (c *Config) Network_disconnect() error {

}
*/
func (c *Config) Network_send() error {
  var err error

  t1 := time.Now()
  _, err = c._connect.Write([]byte(c.Command))
  t2 := time.Now()
  if err != nil {
        c.ch_message <- fmt.Sprintf("e|:|%s: send failed: %s  error: %s", mod_name, c.network_connection_string, err.Error())
        return err
  }
  if DEBUG.enable {
        c.ch_message <- fmt.Sprintf("d|:|%s: host: %s  time: %s  send command: %s", mod_name, c.network_connection_string, t2.Sub(t1), c.Command)
  }

  return nil
}

func (c *Config) Network_receive() error {
  var err error
/*
  connection_string := c.Network.Host+":"+fmt.Sprintf("%d", c.Network.Port)
*/

  reply := make([]byte, 1024)

  t1 := time.Now()
  _, err = c._connect.Read(reply)
  t2 := time.Now()
  if err != nil {
    c.ch_message <- fmt.Sprintf("e|:|%s: receive failed: %s  error: %s", mod_name, c.network_connection_string, err.Error())
	return err
  }
  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: host: %s  time: %s  receive raw data: %s", mod_name, c.network_connection_string, t2.Sub(t1), string(reply))
  }

  c.Type = strings.ToLower(c.Type)

  if c.Type == "systec" || regexp.MustCompile(`(?is)^b[uy].*at`).MatchString(c.Type) {
    c.Processing_systec(string(reply))
  }

  return nil
}
