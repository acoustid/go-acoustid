package common

import (
	"database/sql"
	"fmt"
	"net"
	"net/url"
	"os"
	"strconv"

	_ "github.com/lib/pq"
	"github.com/rs/zerolog/log"
	"github.com/urfave/cli/v2"
)

func ConcatFlags(slices ...[]cli.Flag) []cli.Flag {
	var result []cli.Flag
	for _, slice := range slices {
		result = append(result, slice...)
	}
	return result
}

type DatabaseCliFlags struct {
	Database    *cli.StringFlag
	Host        *cli.StringFlag
	Port        *cli.IntFlag
	User        *cli.StringFlag
	Password    *cli.StringFlag
	SSLMode     *cli.StringFlag
	SSLRootCert *cli.StringFlag
}

func NewDatabaseCliFlags(prefix string, envPrefix string) *DatabaseCliFlags {
	return &DatabaseCliFlags{
		Database: &cli.StringFlag{
			Name:    prefix + "database",
			Usage:   "Database name",
			EnvVars: []string{envPrefix + "DATABASE"},
		},
		Host: &cli.StringFlag{
			Name:    prefix + "host",
			Usage:   "Database host",
			EnvVars: []string{envPrefix + "HOST"},
		},
		Port: &cli.IntFlag{
			Name:    prefix + "port",
			Usage:   "Database port",
			EnvVars: []string{envPrefix + "PORT"},
		},
		User: &cli.StringFlag{
			Name:    prefix + "user",
			Usage:   "Database user",
			EnvVars: []string{envPrefix + "USER"},
		},
		Password: &cli.StringFlag{
			Name:    prefix + "password",
			Usage:   "Database password",
			EnvVars: []string{envPrefix + "PASSWORD"},
		},
		SSLMode: &cli.StringFlag{
			Name:    prefix + "sslmode",
			Usage:   "Database TLS mode (disable, require, verify-ca, verify-full)",
			Value:   "disable",
			EnvVars: []string{envPrefix + "SSLMODE"},
		},
		SSLRootCert: &cli.StringFlag{
			Name:    prefix + "sslrootcert",
			Usage:   "Path to the CA certificate used to verify the database server",
			EnvVars: []string{envPrefix + "SSLROOTCERT"},
		},
	}
}

func (f *DatabaseCliFlags) Flags() []cli.Flag {
	return []cli.Flag{
		f.Database,
		f.Host,
		f.Port,
		f.User,
		f.Password,
		f.SSLMode,
		f.SSLRootCert,
	}
}

func (f *DatabaseCliFlags) Config(c *cli.Context) *DatabaseConfig {
	cfg := NewDatabaseConfig()
	cfg.Database = f.Database.Get(c)
	cfg.Host = f.Host.Get(c)
	cfg.Port = f.Port.Get(c)
	cfg.User = f.User.Get(c)
	cfg.Password = f.Password.Get(c)
	cfg.SSLMode = f.SSLMode.Get(c)
	cfg.SSLRootCert = f.SSLRootCert.Get(c)
	return cfg
}

type DatabaseConfig struct {
	Database    string
	Host        string
	Port        int
	User        string
	Password    string
	SSLMode     string
	SSLRootCert string
}

func NewDatabaseConfig() *DatabaseConfig {
	return &DatabaseConfig{
		Database: "acoustid",
		Host:     "localhost",
		Port:     5432,
		User:     "acoustid",
		Password: "acoustid",
		SSLMode:  "disable",
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
	sslMode := cfg.SSLMode
	if sslMode == "" {
		sslMode = "disable"
	}
	params.Add("sslmode", sslMode)
	if cfg.SSLRootCert != "" {
		params.Add("sslrootcert", cfg.SSLRootCert)
	}
	u.RawQuery = params.Encode()
	return &u
}

func (cfg *DatabaseConfig) Connect() (*sql.DB, error) {
	// lib/pq silently ignores an unreadable sslrootcert under sslmode=require
	// and carries on without verifying the server, so check it here rather
	// than let a mistyped path quietly become an unverified connection.
	if cfg.SSLRootCert != "" {
		if _, err := os.Stat(cfg.SSLRootCert); err != nil {
			return nil, fmt.Errorf("cannot read sslrootcert %q: %w", cfg.SSLRootCert, err)
		}
	}
	url := cfg.URL().String()
	log.Info().Msgf("Connecting to PostgreSQL at %s:%d using database %s", cfg.Host, cfg.Port, cfg.Database)
	return sql.Open("postgres", url)
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
	sslMode := os.Getenv(prefix + "SSLMODE")
	if sslMode != "" {
		cfg.SSLMode = sslMode
	}
	sslRootCert := os.Getenv(prefix + "SSLROOTCERT")
	if sslRootCert != "" {
		cfg.SSLRootCert = sslRootCert
	}
}
