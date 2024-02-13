package fpstore

import (
	"net"
	"strconv"
	"strings"

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
	EnvVars: []string{"FPSTORE_REDIS_HOST"},
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

func ConnectToRedis(c *cli.Context) (redis.Cmdable, error) {
	host := c.String(RedisHostFlag.Name)
	port := c.Int(RedisPortFlag.Name)
	database := c.Int(RedisDatabaseFlag.Name)
	password := RedisPasswordFlag.Get(c)

	if strings.Contains(host, ",") {
		hosts := strings.Split(host, ",")
		addrs := make(map[string]string, len(hosts))
		for _, h := range hosts {
			addrs[h] = net.JoinHostPort(h, strconv.Itoa(port))
		}
		log.Info().Msgf("Connecting to Redis ring at %s:%d/%d", host, port, database)
		client := redis.NewRing(&redis.RingOptions{
			Addrs:    addrs,
			DB:       database,
			Password: password,
		})
		return client, nil
	} else {
		log.Info().Msgf("Connecting to Redis at %s:%d/%d", host, port, database)
		client := redis.NewClient(&redis.Options{
			Addr:     net.JoinHostPort(host, strconv.Itoa(port)),
			DB:       database,
			Password: password,
		})
		return client, nil
	}
}

func PrepareFingerprintCache(c *cli.Context) (FingerprintCache, error) {
	client, err := ConnectToRedis(c)
	if err != nil {
		return nil, errors.WithMessage(err, "failed to connect to Redis")
	}
	return NewRedisFingerprintCache(client), nil
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
			GatewayCommand,
		},
	}
}
