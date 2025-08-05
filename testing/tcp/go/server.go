package main

import (
	//    "bufio"
	"fmt"
	//    "log"
	"net"
	"time"

	//    "strings"
	"io"
)

var (
	host         string = "localhost"
	port         string = "1234"
	send_message string = `<28.05.25 16:48:05;     0.00;     0.00;     0.00;1;     0.00;     0.00;     0.00;0;     0.00;     0.00;     0.00;0;  0;     0.00;     0.00;     0.00;1;  0;     0.00;     0.00;     0.00;1;  0;     0.00;     0.00;     0.00;1;  0;     0.00;     0.00;     0.00;1;     0.00;     0.00;>`
)

// func main() {
/*
    ln, err := net.Listen("tcp", host + ":" + port)
    if err != nil {
        log.Fatal(err)
    }
    fmt.Printf("Listening host: %s  on port %s\n", host, port)
    conn, err := ln.Accept()
    if err != nil {
        log.Fatal(err)
    }
    for {
//        message, err :=  bufio.NewReader(conn).ReadString('\n')
//        if err != nil {
//            log.Fatal(err)
//        }
//        fmt.Print("Message Received:", string(message))
        fmt.Printf("msg_count: %d  message send: %s\n", msg_count, send_message)
        conn.Write([]byte(send_message + "\n"))
		time.Sleep(time.Second * 4)
		msg_count++
    }
}


*/

//  l, err := net.Listen("tcp4", host + ":" + port)
//  if err != nil {
//   //log.Fatal(err)
//   fmt.Printf("Fatal: %s\n", err.Error())
//  }
//  defer l.Close()

//  var done chan bool

//  for {
//   c, err := l.Accept()
//   if err != nil {
//    fmt.Println(err)
//    return
//   }
//   go handleConnection(c, done)
// /*
//   for {
//     select {
//     case <-done:
// 		fmt.Printf(">>>>>>>> done\n")
//         c.Close()
//     }
//   }*/
//  }
//}

func handleConnection(c net.Conn, done chan bool) {
	defer c.Close() // Release resources.
	msg_count := 0
	//buf := make([]byte, 2048)

	fmt.Printf("count: %d  Serving %s\n", msg_count, c.RemoteAddr().String())

	for {

		_, err := c.Write([]byte(fmt.Sprintf("msg count: %d  message: ", msg_count) + send_message + "\n"))
		if err != nil {
			if err == io.EOF {
				//c.Close()
				//c = nil
				//continue
			}
			if err, ok := err.(net.Error); ok && err.Timeout() {
				//continue
			} else {
				fmt.Println("I am here", err.Error())
				//done<-true
				return
			}
		}
		fmt.Printf("msg_count: %d  message send: %s\n", msg_count, send_message)
		//c.Write([]byte(send_message + "\n"))
		msg_count++
		time.Sleep(time.Second * 2)
	}
}
