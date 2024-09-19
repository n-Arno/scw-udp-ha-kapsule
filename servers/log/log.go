package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
)

func Log(w http.ResponseWriter, r *http.Request) {
	method := r.Method
	if method == "POST" {
		w.Header().Set("Content-Type", "text/plain")
		reqBody, err := ioutil.ReadAll(r.Body)
		if err != nil {
			panic(err)
		}
		logLine := string(reqBody) + "<br />\n"

		f, err := os.OpenFile("out/log.txt", os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0666)
		if err != nil {
			panic(err)
		}

		defer f.Close()
		if _, err = f.Write([]byte(logLine)); err != nil {
			panic(err)
		}
		fmt.Fprintf(w, "ok")
	} else {
		w.Header().Set("Content-Type", "text/html")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		f, err := os.ReadFile("out/log.txt")
		if err == nil {
			fmt.Fprintf(w, string(f))
		} else {
			fmt.Fprintf(w, "--no log--\n")
		}
	}
}

func main() {
	fmt.Println("Starting server http://0.0.0.0:80")
	_ = http.ListenAndServe(":80", http.HandlerFunc(Log))
}
