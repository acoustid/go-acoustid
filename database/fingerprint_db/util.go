package fingerprint_db

import (
	"database/sql/driver"
	"fmt"
	"strconv"
	"strings"
)

type Int32Array []int32
type Uint32Array []uint32

func (a Uint32Array) Value() (driver.Value, error) {
	if a == nil {
		return nil, nil
	}
	var builder strings.Builder
	builder.WriteRune('{')
	for i, item := range a {
		if i > 0 {
			builder.WriteRune(',')
		}
		builder.WriteString(strconv.FormatInt(int64(int32(item)), 10))
	}
	builder.WriteRune('}')
	return builder.String(), nil
}

func (a *Uint32Array) Scan(src interface{}) error {
	switch src := src.(type) {
	case []byte:
		return a.scanString(string(src))
	case string:
		return a.scanString(src)
	case nil:
		*a = nil
		return nil
	}
	return fmt.Errorf("cannot convert %T to Uint32Array", src)
}

func (a *Uint32Array) scanString(src string) error {
	if strings.HasPrefix(src, "{") && strings.HasSuffix(src, "}") {
		src = strings.Trim(src, "{}")
	}
	items := strings.Split(src, ",")
	result := make([]uint32, len(items))
	for i, item := range items {
		value, err := strconv.ParseInt(item, 10, 32)
		if err != nil {
			return err
		}
		result[i] = uint32(int32(value))
	}
	*a = result
	return nil
}

func (a Int32Array) Value() (driver.Value, error) {
	if a == nil {
		return nil, nil
	}
	var builder strings.Builder
	builder.WriteRune('{')
	for i, item := range a {
		if i > 0 {
			builder.WriteRune(',')
		}
		builder.WriteString(strconv.FormatInt(int64(int32(item)), 10))
	}
	builder.WriteRune('}')
	return builder.String(), nil
}

func (a *Int32Array) Scan(src interface{}) error {
	switch src := src.(type) {
	case []byte:
		return a.scanString(string(src))
	case string:
		return a.scanString(src)
	case nil:
		*a = nil
		return nil
	}
	return fmt.Errorf("cannot convert %T to Int32Array", src)
}

func (a *Int32Array) scanString(src string) error {
	if strings.HasPrefix(src, "{") && strings.HasSuffix(src, "}") {
		src = strings.Trim(src, "{}")
	}
	items := strings.Split(src, ",")
	result := make([]int32, len(items))
	for i, item := range items {
		value, err := strconv.ParseInt(item, 10, 32)
		if err != nil {
			return err
		}
		result[i] = int32(value)
	}
	*a = result
	return nil
}
