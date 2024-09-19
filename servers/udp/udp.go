package main

import (
	"bytes"
	"fmt"
	"log"
	"net"
	"net/http"
	"strings"
	"time"
)

func main() {
	fmt.Println("Starting udp server 0.0.0.0:1053")
	udpServer, err := net.ListenPacket("udp", ":1053")
	if err != nil {
		log.Fatal(err)
	}
	defer udpServer.Close()

	for {
		buf := make([]byte, 1024)
		_, addr, err := udpServer.ReadFrom(buf)
		if err != nil {
			continue
		}
		go response(udpServer, addr, buf)
	}

}

func response(udpServer net.PacketConn, addr net.Addr, buf []byte) {
	time := time.Now().Format(time.ANSIC)
	cleanMsg := bytes.Trim(buf, "\x00")
	responseStr := fmt.Sprintf("time received: %v. Message received: %v.", time, string(cleanMsg))

	log := strings.NewReader(responseStr)
	_, _ = http.Post("http://log", "text/plain", log)

	udpServer.WriteTo([]byte(responseStr), addr)
}
