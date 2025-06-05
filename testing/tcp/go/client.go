package main

import (
    "bufio"
    "fmt"
    "log"
    "net"
    //"os"
)

func main() {
    conn, err := net.Dial("tcp", "localhost:1234")
    if err != nil {
        log.Fatal(err)
    }
    for {
        //reader := bufio.NewReader(os.Stdin)
        //fmt.Print("Text to send: ")
        //text, _ := reader.ReadString('\n')
        //fmt.Fprintf(conn, text + "\n")
        message, _ := bufio.NewReader(conn).ReadString('\n')
        fmt.Print("Message from server string: %s\n", message)
		
		buf := make([]byte, 1024)
		n, _ := bufio.NewReader(conn).Read(buf)
		fmt.Printf("Message from server count: %d  string: %s\n", n, string(buf))
		
		
    }
}