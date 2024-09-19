package main

import (
	"fmt"
	"math/rand/v2"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	args := os.Args
	if len(args) == 1 {
		println("Usage: client <server address>")
		os.Exit(1)
	}

	c := make(chan os.Signal)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-c
		println("Exiting...")
		os.Exit(0)
	}()

	for {
		ping(args[1])
		time.Sleep(500 * time.Millisecond)
	}
}

func ping(a string) {
	udpServer, err := net.ResolveUDPAddr("udp", fmt.Sprintf("%s:1053", a))

	if err != nil {
		println("ResolveUDPAddr failed:", err.Error())
		os.Exit(1)
	}

	conn, err := net.DialUDP("udp", nil, udpServer)
	if err != nil {
		println("Listen failed:", err.Error())
		os.Exit(1)
	}

	//close the connection
	defer conn.Close()

	_, err = conn.Write([]byte(fmt.Sprintf("rand(1000)=%v", rand.IntN(1000))))
	if err != nil {
		println("Write data failed:", err.Error())
		os.Exit(1)
	}

	// buffer to get data
	received := make([]byte, 1024)
	_, err = conn.Read(received)
	if err != nil {
		println("Read data failed:", err.Error())
		os.Exit(1)
	}

	println(string(received))
}
