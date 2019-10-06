package common

import (
	"fmt"
	"net"
	"net/url"
	"os"
	"strconv"
)

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

func NewTestDatabaseConfig(name string) *DatabaseConfig {
	cfg := NewDatabaseConfig()
	cfg.Port += 10000
	cfg.Name = name
	cfg.readEnv("ACOUSTID_TEST_POSTGRESQL_")
	return cfg
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

func (cfg *DatabaseConfig) readEnv(prefix string) {
	name := os.Getenv(prefix + "NAME")
	if name != "" {
		cfg.Name = name
	}
	host := os.Getenv(prefix + "HOST")
	if host != "" {
		cfg.Host = host
	}
	portStr := os.Getenv(prefix + "PORT")
	if portStr != "" {
		port, err := strconv.ParseInt(portStr, 10, 32)
		if err == nil {
			cfg.Port = int(port)
		}
	}
	username := os.Getenv(prefix + "USERNAME")
	if username != "" {
		cfg.Username = username
	}
	password := os.Getenv(prefix + "PASSWORD")
	if password != "" {
		cfg.Password = password
	}
}
