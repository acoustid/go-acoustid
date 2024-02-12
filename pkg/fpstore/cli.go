package fpstore

import (
	"net"
	"strconv"

	"github.com/rs/zerolog/log"

	"github.com/acoustid/go-acoustid/common"
	"github.com/acoustid/go-acoustid/pkg/fpindex"
	"github.com/pkg/errors"
	"github.com/redis/go-redis/v9"
	"github.com/urfave/cli/v2"
)

var PostgresHost = cli.StringFlag{
	Name:    "postgres-host",
	Usage:   "Postgres server address",
	Value:   "localhost",
	EnvVars: []string{"FPSTORE_POSTGRES_HOST"},
}

var PostgresPort = cli.IntFlag{
	Name:    "postgres-port",
	Usage:   "Postgres server port",
	Value:   5432,
	EnvVars: []string{"FPSTORE_POSTGRES_PORT"},
}

var PostgresUser = cli.StringFlag{
	Name:    "postgres-user",
	Usage:   "Postgres server user",
	Value:   "acoustid",
	EnvVars: []string{"FPSTORE_POSTGRES_USER"},
}

var PostgresPassword = cli.StringFlag{
	Name:    "postgres-password",
	Usage:   "Postgres server password",
	Value:   "",
	EnvVars: []string{"FPSTORE_POSTGRES_PASSWORD"},
}

var PostgresDatabase = cli.StringFlag{
	Name:    "postgres-database",
	Usage:   "Postgres server database",
	Value:   "acoustid",
	EnvVars: []string{"FPSTORE_POSTGRES_DATABASE"},
}

var RedisHostFlag = cli.StringFlag{
	Name:    "redis-host",
	Usage:   "Redis server address",
	Value:   "localhost:6379",
	EnvVars: []string{"FPSTORE_REDIS_ADDR"},
}

var RedisPortFlag = cli.IntFlag{
	Name:    "redis-port",
	Usage:   "Redis server port",
	Value:   6379,
	EnvVars: []string{"FPSTORE_REDIS_PORT"},
}

var RedisDatabaseFlag = cli.IntFlag{
	Name:    "redis-database",
	Usage:   "Redis server database",
	Value:   0,
	EnvVars: []string{"FPSTORE_REDIS_DATABASE"},
}

var RedisPasswordFlag = cli.StringFlag{
	Name:    "redis-password",
	Usage:   "Redis server password",
	Value:   "",
	EnvVars: []string{"FPSTORE_REDIS_PASSWORD"},
}

var ListenHostFlag = cli.StringFlag{
	Name:    "listen-host",
	Usage:   "Listen address",
	Value:   "localhost",
	EnvVars: []string{"FPSTORE_LISTEN_HOST"},
}

var ListenPortFlag = cli.IntFlag{
	Name:    "listen-port",
	Usage:   "Listen port",
	Value:   4659,
	EnvVars: []string{"FPSTORE_LISTEN_PORT"},
}

var IndexHostFlag = cli.StringFlag{
	Name:    "index-host",
	Usage:   "Index server address",
	Value:   "localhost",
	EnvVars: []string{"FPSTORE_INDEX_HOST"},
}

var IndexPortFlag = cli.IntFlag{
	Name:    "index-port",
	Usage:   "Index server port",
	Value:   6080,
	EnvVars: []string{"FPSTORE_INDEX_PORT"},
}

func PrepareFingerprintCache(c *cli.Context) (FingerprintCache, error) {
	return NewRedisFingerprintCache(&redis.Options{
		Addr:     net.JoinHostPort(c.String(RedisHostFlag.Name), strconv.Itoa(c.Int(RedisPortFlag.Name))),
		Password: c.String(RedisPasswordFlag.Name),
		DB:       c.Int(RedisDatabaseFlag.Name),
	}), nil
}

func PrepareFingerprintStore(c *cli.Context) (FingerprintStore, error) {
	var config common.DatabaseConfig
	config.Host = c.String(PostgresHost.Name)
	config.Port = c.Int(PostgresPort.Name)
	config.User = c.String(PostgresUser.Name)
	config.Password = c.String(PostgresPassword.Name)
	config.Database = c.String(PostgresDatabase.Name)

	db, err := config.Connect()
	if err != nil {
		return nil, errors.WithMessage(err, "failed to connect to database")
	}

	return NewPostgresFingerprintStore(db), nil
}

func PrepareFingerprintIndex(c *cli.Context) (FingerprintIndex, error) {
	config := fpindex.NewIndexConfig()
	config.Host = c.String(IndexHostFlag.Name)
	config.Port = c.Int(IndexPortFlag.Name)

	const MaxConnections = 1000
	clientPool := fpindex.NewIndexClientPool(config, MaxConnections)
	return NewFingerprintIndexClient(clientPool), nil
}

func PrepareAndRunServer(c *cli.Context) error {
	fingerprintStore, err := PrepareFingerprintStore(c)
	if err != nil {
		return errors.WithMessage(err, "failed to initialize fingerprint store")
	}

	fingerprintIndex, err := PrepareFingerprintIndex(c)
	if err != nil {
		return errors.WithMessage(err, "failed to initialize fingerprint index")
	}

	fingerprintCache, err := PrepareFingerprintCache(c)
	if err != nil {
		return errors.WithMessage(err, "failed to initialize fingerprint cache")
	}

	service := NewFingerprintStoreService(fingerprintStore, fingerprintIndex, fingerprintCache)

	listenAddr := net.JoinHostPort(c.String(ListenHostFlag.Name), strconv.Itoa(c.Int(ListenPortFlag.Name)))
	log.Info().Msgf("Running gRPC on %s", listenAddr)
	return RunFingerprintStoreServer(listenAddr, service)
}

func BuildCli() *cli.Command {
	serverCommand := &cli.Command{
		Name:  "server",
		Usage: "Runs fpstore gRPC service",
		Flags: []cli.Flag{
			&ListenHostFlag,
			&ListenPortFlag,
			&PostgresHost,
			&PostgresPort,
			&PostgresUser,
			&PostgresPassword,
			&PostgresDatabase,
			&RedisHostFlag,
			&RedisPortFlag,
			&RedisPasswordFlag,
			&RedisDatabaseFlag,
			&IndexHostFlag,
			&IndexPortFlag,
		},
		Action: PrepareAndRunServer,
	}

	return &cli.Command{
		Name:  "fpstore",
		Usage: "AcoustID fingerprint store",
		Subcommands: []*cli.Command{
			serverCommand,
		},
	}
}