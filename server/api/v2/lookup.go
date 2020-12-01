package v2

import (
	"context"
	"log"
	"math"
	"net/http"
	"strconv"
	"time"

	"github.com/acoustid/go-acoustid/chromaprint"
	"github.com/acoustid/go-acoustid/server/services"
)

const MinDuration = 1
const MaxDuration = 32767

type MetaArtist struct {
	XMLName struct{} `json:"-" xml:"track"`
	ID      string   `json:"id" xml:"id"`
	Name    string   `json:"name,omitempty" xml:"name,omitempty"`
}

type MetaRelease struct {
	XMLName struct{} `json:"-" xml:"track"`
	ID      string   `json:"id" xml:"id"`
	Title   string   `json:"title,omitempty" xml:"title,omitempty"`
}

type MetaMedium struct {
	XMLName    struct{}    `json:"-" xml:"track"`
	ID         string      `json:"id" xml:"id"`
	Position   int32       `json:"position,omitempty" xml:"position,omitempty"`
	TrackCount int32       `json:"track_count,omitempty" xml:"track_count,omitempty"`
	Format     string      `json:"format,omitempty" xml:"format,omitempty"`
	Release    MetaRelease `json:"release,omitempty" xml:"release,omitempty"`
}

type MetaTrack struct {
	XMLName  struct{}     `json:"-" xml:"track"`
	ID       string       `json:"id" xml:"id"`
	Title    string       `json:"title,omitempty" xml:"title,omitempty"`
	Duration float64      `json:"duration,omitempty" xml:"duration,omitempty"`
	Artists  []MetaArtist `json:"artists,omitempty" xml:"artist,omitempty"`
	Position int32        `json:"position,omitempty" xml:"position,omitempty"`
}

type MetaRecording struct {
	XMLName  struct{}    `json:"-" xml:"recording"`
	ID       string      `json:"id" xml:"id"`
	Duration float64     `json:"duration,omitempty" xml:"duration,omitempty"`
	Tracks   []MetaTrack `json:"tracks,omitempty" xml:"tracks,omitempty"`
}

type LookupResult struct {
	ID         string          `json:"id" xml:"id"`
	Score      float64         `json:"score" xml:"score"`
	Recordings []MetaRecording `json:"recordings,omitempty" xml:"recordings,omitempty"`
	XMLName    struct{}        `json:"-" xml:"result"`
}

type LookupResponse struct {
	Status  string         `json:"status" xml:"status"`
	Results []LookupResult `json:"results" xml:"results>result"`
	XMLName struct{}       `json:"-" xml:"response"`
}

type LookupHandler struct {
	Searcher services.FingerprintSearcher
}

func NewLookupHandler(searcher services.FingerprintSearcher) http.Handler {
	return &LookupHandler{Searcher: searcher}
}

func (handler *LookupHandler) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	format, err := GetResponseFormat(r)
	if err != nil {
		WriteError(rw, DefaultFormat, NewError(ERROR_INVALID_FORMAT, "invalid format"))
		return
	}

	durationStr := r.FormValue("duration")
	if durationStr == "" {
		WriteError(rw, format, NewError(ERROR_MISSING_PARAMETER, "missing parameter 'duration'"))
		return
	}
	durationFloat, err := strconv.ParseFloat(durationStr, 64)
	if err != nil || durationFloat < MinDuration || durationFloat >= MaxDuration {
		if err != nil {
			log.Printf("Invalid duration: %s", err)
		}
		WriteError(rw, format, NewError(ERROR_INVALID_DURATION, "invalid duration"))
		return
	}
	duration := time.Duration(math.Round(durationFloat * float64(time.Second)))
	log.Printf("duration %v", duration)

	fingerprintStr := r.FormValue("fingerprint")
	if fingerprintStr == "" {
		WriteError(rw, format, NewError(ERROR_MISSING_PARAMETER, "missing parameter 'fingerprint'"))
		return
	}
	fingerprint, err := chromaprint.ParseFingerprintString(fingerprintStr)
	if err != nil {
		log.Printf("Invalid fingerprint: %s", err)
		WriteError(rw, format, NewError(ERROR_INVALID_FINGERPRINT, "invalid fingerprint"))
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), time.Second)
	defer cancel()

	results, err := handler.Searcher.Search(ctx, fingerprint, duration)
	if err != nil {
		log.Printf("Failed to search: %v", err)
		WriteError(rw, format, NewError(ERROR_INTERNAL, "internal error"))
		return
	}

	response := LookupResponse{
		Status:  "ok",
		Results: make([]LookupResult, len(results)),
	}
	for i, result := range results {
		response.Results[i] = LookupResult{
			ID:    result.TrackGID,
			Score: result.Score,
		}
	}

	err = WriteResponse(rw, http.StatusOK, format, response)
	if err != nil {
		log.Printf("Failed to write response: %v", err)
		WriteError(rw, format, NewError(ERROR_INTERNAL, "internal error"))
		return
	}
}
