package scales

import (
	"fmt"
	"net"
	"regexp"
	"strings"
	"time"
)

func (c *Config) Network_connect() error {
	var err error

	if !regexp.MustCompile(`(?is)^udp|tcp`).MatchString(c.Network.Protocol) {
		c.Network.Protocol = "tcp"
	}

	t1 := time.Now()
	c._connect, err = net.Dial(c.Network.Protocol, c.network_connection_string)
	if err != nil {
		c.ch_message <- fmt.Sprintf("e|:|%s: dial failed: %s  error: %s", mod_name, c.network_connection_string, err.Error())
		return err
	}
	t2 := time.Now()

	c.ch_message <- fmt.Sprintf("i|:|%s: scale id: %d  connect: %s  time: %s", mod_name, c.Id_scale, c.network_connection_string, t2.Sub(t1))
	return nil
}

/*
func (c *Config) Network_disconnect() error {

}
*/
func (c *Config) Network_send() error {
	var err error

	c._connect.SetWriteDeadline(time.Now().Add(time.Millisecond * read_write_timeout))

	message := c.Create_message()

	t1 := time.Now()
	_, err = c._connect.Write(message)
	if err != nil {
		c.ch_message <- fmt.Sprintf("e|:|%s: send failed: %s  error: %s", mod_name, c.network_connection_string, err.Error())
		return err
	}
	t2 := time.Now()
	if DEBUG.enable {
		c.ch_message <- fmt.Sprintf("d|:|%s: host: %s  time: %s  send command: %s", mod_name, c.network_connection_string, t2.Sub(t1), c.Command)
	}

	return nil
}

func (c *Config) Network_receive() error {
	buf := make([]byte, 1024)

	c._connect.SetReadDeadline(time.Now().Add(time.Millisecond * read_write_timeout))

	t1 := time.Now()
	n, err := c._connect.Read(buf)
	if err != nil {
		c.ch_message <- fmt.Sprintf("e|:|%s: receive failed: %s  error: %s", mod_name, c.network_connection_string, err.Error())
		return err
	}
	t2 := time.Now()
	message := string(buf[:n])
	if DEBUG.enable {
		c.ch_message <- fmt.Sprintf("d|:|%s: host: %s  time: %s  receive raw count: %d  data: %s", mod_name, c.network_connection_string, t2.Sub(t1), n, message)
	}

	if n == 0 {
		return nil
	}

	c.Type = strings.ToLower(c.Type)

	if c.Type == "systec" || regexp.MustCompile(`(?is)^b[uy].*at`).MatchString(c.Type) {
		c.Processing_systec(message)
	} else if regexp.MustCompile(`(?is)^schenck`).MatchString(c.Type) {
		c.Processing_schenck(message)
	} else if regexp.MustCompile(`(?is)^autobelazes`).MatchString(c.Type) {
		c.Processing_autobelazes(message)
	}

	return nil
}

func (c *Config) Create_message() []byte {
	var message string

	if c.Type == "systec" || regexp.MustCompile(`(?is)^b[uy].*at`).MatchString(c.Type) {
		message = c.Command
	} else if regexp.MustCompile(`(?is)^schenck`).MatchString(c.Type) {
		request := fmt.Sprintf("%s%s%s", c.Command, string(DLE), string(ETX))
		bcc, _ := c.hash_bcc([]byte(request))
		message = fmt.Sprintf("%s%s%s", string(STX), request, bcc)
	} else if regexp.MustCompile(`(?is)^autobelazes`).MatchString(c.Type) {
		message = c.Command
	}

	if DEBUG.enable {
		c.ch_message <- fmt.Sprintf("d|:|%s: create message: '%v'", mod_name, message)
	}

	return []byte(message)
}
