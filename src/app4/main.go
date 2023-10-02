package main

import (
	"fmt"
	"net/http"
)

func helloWorldHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello, app4!")
}

func main() {
	http.HandleFunc("/", helloWorldHandler)
	http.ListenAndServe(":8080", nil)
}
