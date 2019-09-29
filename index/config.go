package index

import (
	"fmt"
	"net"
	"net/url"
	"strconv"
)

type IndexConfig struct {
	Host string
	Port int
}

func NewIndexConfig() *IndexConfig {
	return &IndexConfig{
		Host: "localhost",
		Port: 6080,
	}
}

type DatabaseConfig struct {
	Name     string
	Host     string
	Port     int
	Username string
	Password string
}

func NewDatabaseConfig() *DatabaseConfig {
	return &DatabaseConfig{
		Name:     "acoustid",
		Host:     "localhost",
		Port:     5432,
		Username: "acoustid",
		Password: "acoustid",
	}
}

func (cfg *DatabaseConfig) URL() *url.URL {
	var u url.URL
	u.Scheme = "postgresql"
	u.User = url.UserPassword(cfg.Username, cfg.Password)
	u.Host = net.JoinHostPort(cfg.Host, strconv.Itoa(cfg.Port))
	u.Path = fmt.Sprintf("/%s", cfg.Name)
	params := url.Values{}
	params.Add("sslmode", "disable")
	u.RawQuery = params.Encode()
	return &u
}
