package v2

import "net/http"

type Response interface {
	WriteResponse(rw http.ResponseWriter)
}
