package v2

import (
	"bytes"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"net/http"
)

type ResponseFormat interface {
	ContentType() string
	Marshal(response interface{}) ([]byte, error)
}

type JSON struct {
}

func (f JSON) ContentType() string {
	return "application/json"
}

func (f JSON) Marshal(response interface{}) ([]byte, error) {
	return json.Marshal(response)
}

type JSONP struct {
	Callback string
}

func (f JSONP) ContentType() string {
	return "application/javascript"
}

func (f JSONP) Marshal(response interface{}) ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteString(f.Callback)
	buf.WriteRune('(')
	err := json.NewEncoder(&buf).Encode(response)
	if err != nil {
		return nil, err
	}
	buf.WriteRune(')')
	return buf.Bytes(), nil
}

type XML struct {
}

func (f XML) ContentType() string {
	return "application/xml"
}

func (f XML) Marshal(response interface{}) ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteString(xml.Header)
	err := xml.NewEncoder(&buf).Encode(response)
	if err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

var DefaultFormat = &JSON{}

func GetResponseFormat(r *http.Request) (ResponseFormat, error) {
	format := r.FormValue("format")
	if format == "" {
		return DefaultFormat, nil
	}
	if format == "json" {
		return &JSON{}, nil
	}
	if format == "jsonp" {
		callback := r.FormValue("jsoncallback")
		if callback == "" {
			callback = "jsonAcoustidApi"
		}
		return &JSONP{Callback: callback}, nil
	}
	if format == "xml" {
		return &XML{}, nil
	}
	return nil, errors.New("invalid format")
}

func WriteResponse(rw http.ResponseWriter, status int, format ResponseFormat, response interface{}) error {
	content, err := format.Marshal(response)
	if err != nil {
		return fmt.Errorf("failed to marshal response: %w", err)
	}

	rw.Header().Set("Content-Type", format.ContentType())
	rw.WriteHeader(status)
	rw.Write(content)
	return nil
}
