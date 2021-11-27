package api

import (
	"compress/gzip"
	"net/http"
)

func DecompressRequestBody(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Content-Encoding") == "gzip" {
			reader, err := gzip.NewReader(r.Body)
			if err != nil {
				r.Body.Close()
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			r.Body = reader
		}
		next.ServeHTTP(w, r)
	})
}
