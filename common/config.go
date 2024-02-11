package common

import (
	"database/sql"
	"fmt"
	"net"
	"net/url"
	"os"
	"strconv"

	_ "github.com/lib/pq"
)

type DatabaseConfig struct {
	Database string
	Host     string
	Port     int
	User     string
	Password string
}

func NewDatabaseConfig() *DatabaseConfig {
	return &DatabaseConfig{
		Database: "acoustid",
		Host:     "localhost",
		Port:     5432,
		User:     "acoustid",
		Password: "acoustid",
	}
}

func NewTestDatabaseConfig(name string) *DatabaseConfig {
	cfg := NewDatabaseConfig()
	cfg.Port += 10000
	cfg.Database = name
	cfg.readEnv("ACOUSTID_TEST_POSTGRESQL_")
	return cfg
}

func (cfg *DatabaseConfig) URL() *url.URL {
	var u url.URL
	u.Scheme = "postgresql"
	if cfg.Password == "" {
		u.User = url.User(cfg.User)
	} else {
		u.User = url.UserPassword(cfg.User, cfg.Password)
	}
	u.Host = net.JoinHostPort(cfg.Host, strconv.Itoa(cfg.Port))
	u.Path = fmt.Sprintf("/%s", cfg.Database)
	params := url.Values{}
	params.Add("sslmode", "disable")
	u.RawQuery = params.Encode()
	return &u
}

func (cfg *DatabaseConfig) Connect() (*sql.DB, error) {
	return sql.Open("postgres", cfg.URL().String())
}

func (cfg *DatabaseConfig) readEnv(prefix string) {
	name := os.Getenv(prefix + "NAME")
	if name != "" {
		cfg.Database = name
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
		cfg.User = username
	}
	password := os.Getenv(prefix + "PASSWORD")
	if password != "" {
		cfg.Password = password
	}
}
