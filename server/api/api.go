package api

import (
	"net/http"

	v2 "github.com/acoustid/go-acoustid/server/api/v2"
	"github.com/acoustid/go-acoustid/server/services"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type API struct {
	Mux                 *http.ServeMux
	FingerprintSearcher services.FingerprintSearcher
}

func NewAPI() *API {
	ws := &API{
		Mux: http.NewServeMux(),
	}

	ws.Mux.Handle("/metrics", promhttp.Handler())

	ws.Mux.HandleFunc("/alive", func(rw http.ResponseWriter, r *http.Request) {
		rw.WriteHeader(http.StatusOK)
		rw.Write([]byte("I'm alive\n"))
	})

	ws.Mux.HandleFunc("/ready", func(rw http.ResponseWriter, r *http.Request) {
		rw.WriteHeader(http.StatusOK)
		rw.Write([]byte("I'm ready\n"))
	})

	v2Mux := http.NewServeMux()

	v2Mux.HandleFunc("/lookup", func(rw http.ResponseWriter, r *http.Request) {
		handler := v2.NewLookupHandler(ws.FingerprintSearcher)
		handler.ServeHTTP(rw, r)
	})

	v2Mux.HandleFunc("/submit", func(rw http.ResponseWriter, r *http.Request) {
		http.Error(rw, "Not implemented yet.", http.StatusInternalServerError)
	})

	v2Mux.HandleFunc("/submission_status", func(rw http.ResponseWriter, r *http.Request) {
		http.Error(rw, "Not implemented yet.", http.StatusInternalServerError)
	})

	v2Mux.HandleFunc("/fingerprint", func(rw http.ResponseWriter, r *http.Request) {
		http.Error(rw, "Not implemented yet.", http.StatusInternalServerError)
	})

	ws.Mux.Handle("/v2/", DecompressRequestBody(v2Mux))

	return ws
}

func (ws *API) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	ws.Mux.ServeHTTP(rw, r)
}

// ListenAndServe listens on the TCP network address addr and
// responds to HTTP requests as they come.
//
// ListenAndServe always returns a non-nil error.
func (ws *API) ListenAndServe(addr string) error {
	return http.ListenAndServe(addr, ws)
}
