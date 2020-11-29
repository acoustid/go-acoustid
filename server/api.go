package server

import (
	"net/http"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"strconv"
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

const MinDuration = 1
const MaxDuration = 32767

type ErrorDetails struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type ErrorResponse struct {
	Status string       `json:"status"`
	Error  ErrorDetails `json:"error"`
}

type WebService struct {
	Mux *http.ServeMux
}

func NewWebService() *WebService {
	ws := &WebService{
		Mux: http.NewServeMux(),
	}
	ws.Mux.HandleFunc("/v2/lookup", ws.HandleV2Lookup)
	return ws
}

func (ws *WebService) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ws.Mux.ServeHTTP(w, r)
}

func Error(w http.ResponseWriter, status int, errorCode int, errorMessage string) {
	response := ErrorResponse{
		Status: "error",
		Error: ErrorDetails{
			Code:    errorCode,
			Message: errorMessage,
		},
	}

	contentType := "application/json"
	content, err := json.Marshal(&response)
	if err != nil {
		if errorCode == ERROR_INTERNAL {
			content = []byte("internal error")
			contentType = "text/plain"
		} else {
			Error(w, http.StatusInternalServerError, ERROR_INTERNAL, "internal error")
			return
		}
	}

	w.Header().Set("Content-Type", contentType)
	w.WriteHeader(status)
	w.Write(content)
}

func GetFormat(r *http.Request) (string, error) {
	format := r.FormValue("format")
	if format == "" {
		format = "json"
	}
	if format != "json" && format != "xml" {
		return "", errors.New("invalid format")
	}
	return format, nil
}

func (ws *WebService) HandleV2Lookup(w http.ResponseWriter, r *http.Request) {
	err := r.ParseForm()
	if err != nil {
		Error(w, http.StatusBadRequest, ERROR_INTERNAL, "unable to parse HTTP request data")
		return
	}

	format, err := GetFormat(r)
	if err != nil {
		Error(w, http.StatusBadRequest, ERROR_INVALID_FORMAT, "invalid format")
		return
	}

	durationStr := r.FormValue("duration")
	if durationStr == "" {
		Error(w, http.StatusBadRequest, ERROR_MISSING_PARAMETER, "missing parameter 'duration'")
		return
	}
	duration, err := strconv.ParseFloat(durationStr, 64)
	log.Printf("Duration %v", duration)
	if err != nil || duration < MinDuration || duration >= MaxDuration {
		if err != nil {
			log.Printf("Invalid duration: %s", err)
		}
		Error(w, http.StatusBadRequest, ERROR_INVALID_DURATION, "invalid duration")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf("{%s}", format)))
}

func RunWebService() error {
	ws := NewWebService()
	return http.ListenAndServe(":8080", ws)
}
