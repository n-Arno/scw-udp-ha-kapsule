all:
	GOOS=linux GOARCH=amd64 go build -ldflags "-s -w" -o client-linux-amd64 client.go
	GOOS=linux GOARCH=arm64 go build -ldflags "-s -w" -o client-linux-arm64 client.go
	GOOS=windows GOARCH=amd64 go build -ldflags "-s -w" -o client-windows-amd64.exe client.go
	GOOS=darwin GOARCH=amd64 go build -ldflags "-s -w" -o client-darwin-amd64 client.go
	GOOS=darwin GOARCH=arm64 go build -ldflags "-s -w" -o client-darwin-arm64 client.go

test:
	go build client.go

clean:
	- rm -rf client-* client
