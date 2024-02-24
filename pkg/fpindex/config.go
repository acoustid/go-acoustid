package fpindex

import "time"

type IndexConfig struct {
	Host         string
	Port         int
	MaxKeepAlive time.Duration
	PingInterval time.Duration
}

func NewIndexConfig() *IndexConfig {
	return &IndexConfig{
		Host:         "localhost",
		Port:         6080,
		MaxKeepAlive: 60 * time.Second,
		PingInterval: 1 * time.Second,
	}
}
