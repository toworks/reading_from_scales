package scales

import (
	"fmt"
    "time"
	"strings"
	"net"
)


func (c *Config) Connect() {
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
  }
  if DEBUG.enable {
	c.ch_message <- fmt.Sprintf("d|:|%s: connect time: %s", mod_name, t2.Sub(t1))
  }
}

func (c *Config) Write() {
  var err error
  connection_string := c.Network.Host+":"+fmt.Sprintf("%d", c.Network.Port)
  cycle := 1000

	timer := time.NewTicker(time.Duration(cycle) * time.Millisecond)
	for _ = range timer.C {
fmt.Printf(">>>>>>>>>>>>>>>>\n")
//						servAddr := "10.27.226.67:25687"
//						tcpAddr, err := net.ResolveTCPAddr("tcp", servAddr)
//						if err != nil {
//							println("ResolveTCPAddr failed:", err.Error())
//							os.Exit(1)
//						}

//						conn, err := net.DialTCP("tcp", nil, tcpAddr)
//						if err != nil {
//							println("Dial failed:", err.Error())
//							os.Exit(1)
//						}

						_, err = c.connTCP.Write([]byte(c.Command))
						if err != nil {
							c.ch_message <- fmt.Sprintf("e|:|%s: write failed: %s  error: %s", mod_name, connection_string, err.Error())
						}

	if DEBUG.enable {
		c.ch_message <- fmt.Sprintf("d|:|%s: send command: %s", mod_name, c.Command)
	}

c.Read()
/*
						reply := make([]byte, 1024)

						_, err = c.connTCP.Read(reply)
						if err != nil {
							println("Write to server failed:", err.Error())
							//os.Exit(1)
						}

						println("reply from server=", string(reply))
*/
						//c.connTCP.Close()
	
	}
}

func (c *Config) Read() {
  var err error
  connection_string := c.Network.Host+":"+fmt.Sprintf("%d", c.Network.Port)

  reply := make([]byte, 1024)

  t1 := time.Now()
  _, err = c.connTCP.Read(reply)
  t2 := time.Now()
  if err != nil {
	c.ch_message <- fmt.Sprintf("e|:|%s: read failed: %s  error: %s", mod_name, connection_string, err.Error())
  }
  if DEBUG.enable {
	c.ch_message <- fmt.Sprintf("d|:|%s: raw data: %s", mod_name, string(reply))
	c.ch_message <- fmt.Sprintf("d|:|%s: read time: %s", mod_name, t2.Sub(t1))
  }
  
  c.Type = strings.ToLower(c.Type)

  if c.Type == "bullat" {
	c.ProcessingBullat(string(reply))
  }
}

