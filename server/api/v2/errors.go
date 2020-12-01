package v2

import (
	"fmt"
	"log"
	"net/http"
)

const ERROR_INVALID_FORMAT = 1
const ERROR_MISSING_PARAMETER = 2
const ERROR_INVALID_FINGERPRINT = 3
const ERROR_INVALID_APIKEY = 4
const ERROR_INTERNAL = 5
const ERROR_INVALID_USER_APIKEY = 6
const ERROR_INVALID_UUID = 7
const ERROR_INVALID_DURATION = 8
const ERROR_INVALID_BITRATE = 9
const ERROR_INVALID_FOREIGNID = 10
const ERROR_INVALID_MAX_DURATION_DIFF = 11
const ERROR_NOT_ALLOWED = 12
const ERROR_SERVICE_UNAVAILABLE = 13
const ERROR_TOO_MANY_REQUESTS = 14
const ERROR_INVALID_MUSICBRAINZ_ACCESS_TOKEN = 15
const ERROR_INSECURE_REQUEST = 16
const ERROR_UNKNOWN_APPLICATION = 17
const ERROR_FINGERPRINT_NOT_FOUND = 18

type ErrorDetails struct {
	Code    int      `json:"code" xml:"code"`
	Message string   `json:"message" xml:"message"`
	XMLName struct{} `json:"-" xml:"error"`
}

type ErrorResponse struct {
	Status  string       `json:"status" xml:"status"`
	Error   ErrorDetails `json:"error" xml:"error"`
	XMLName struct{}     `json:"-" xml:"response"`
}

type Error struct {
	ErrorDetails
}

func (e Error) Error() string {
	return fmt.Sprintf("%v (%v)", e.Message, e.Code)
}

func NewError(errorCode int, errorMessage string) Error {
	return Error{
		ErrorDetails{
			Code:    errorCode,
			Message: errorMessage,
		},
	}
}

func WriteError(rw http.ResponseWriter, format ResponseFormat, e Error) {
	response := ErrorResponse{
		Status: "error",
		Error:  e.ErrorDetails,
	}

	var status int
	switch e.Code {
	case ERROR_INTERNAL:
		status = http.StatusInternalServerError
	case ERROR_SERVICE_UNAVAILABLE:
		status = http.StatusServiceUnavailable
	case ERROR_TOO_MANY_REQUESTS:
		status = http.StatusTooManyRequests
	default:
		status = http.StatusBadRequest
	}

	err := WriteResponse(rw, status, format, response)
	if err != nil {
		log.Printf("failed to write response: %v", err)
		if status == http.StatusInternalServerError {
			rw.WriteHeader(status)
			rw.Write([]byte(e.Message))
		} else {
			WriteError(rw, format, NewError(ERROR_INTERNAL, "internal error"))
		}
	}
}
