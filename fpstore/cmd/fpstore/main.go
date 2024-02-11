package main

import (
	"net"
	"os"
	"strconv"

	_ "github.com/lib/pq"
	"github.com/pkg/errors"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	"github.com/acoustid/go-acoustid/common"
	"github.com/acoustid/go-acoustid/fpstore"
	index_pb "github.com/acoustid/go-acoustid/proto/index"
	"github.com/redis/go-redis/v9"
	log "github.com/sirupsen/logrus"
	"github.com/urfave/cli"
)

var DebugFlag = cli.BoolFlag{
	Name:   "debug, d",
	Usage:  "enable debug mode",
	EnvVar: "FPSTORE_DEBUG",
}

var PostgresHost = cli.StringFlag{
	Name:   "postgres-host",
	Usage:  "Postgres server address",
	Value:  "localhost",
	EnvVar: "FPSTORE_POSTGRES_HOST",
}

var PostgresPort = cli.IntFlag{
	Name:   "postgres-port",
	Usage:  "Postgres server port",
	Value:  5432,
	EnvVar: "FPSTORE_POSTGRES_PORT",
}

var PostgresUser = cli.StringFlag{
	Name:   "postgres-user",
	Usage:  "Postgres server user",
	Value:  "acoustid",
	EnvVar: "FPSTORE_POSTGRES_USER",
}

var PostgresPassword = cli.StringFlag{
	Name:   "postgres-password",
	Usage:  "Postgres server password",
	Value:  "",
	EnvVar: "FPSTORE_POSTGRES_PASSWORD",
}

var PostgresDatabase = cli.StringFlag{
	Name:   "postgres-database",
	Usage:  "Postgres server database",
	Value:  "acoustid",
	EnvVar: "FPSTORE_POSTGRES_DATABASE",
}

var RedisHostFlag = cli.StringFlag{
	Name:   "redis-host",
	Usage:  "Redis server address",
	Value:  "localhost:6379",
	EnvVar: "FPSTORE_REDIS_ADDR",
}

var RedisPortFlag = cli.IntFlag{
	Name:   "redis-port",
	Usage:  "Redis server port",
	Value:  6379,
	EnvVar: "FPSTORE_REDIS_PORT",
}

var RedisDatabaseFlag = cli.IntFlag{
	Name:   "redis-database",
	Usage:  "Redis server database",
	Value:  0,
	EnvVar: "FPSTORE_REDIS_DATABASE",
}

var RedisPasswordFlag = cli.StringFlag{
	Name:   "redis-password",
	Usage:  "Redis server password",
	Value:  "",
	EnvVar: "FPSTORE_REDIS_PASSWORD",
}

var ListenHostFlag = cli.StringFlag{
	Name:   "listen-host",
	Usage:  "Listen address",
	Value:  "localhost",
	EnvVar: "FPSTORE_LISTEN_HOST",
}

var ListenPortFlag = cli.IntFlag{
	Name:   "listen-port",
	Usage:  "Listen port",
	Value:  4659,
	EnvVar: "FPSTORE_LISTEN_PORT",
}

var IndexHostFlag = cli.StringFlag{
	Name:   "index-host",
	Usage:  "Index server address",
	Value:  "localhost",
	EnvVar: "FPSTORE_INDEX_HOST",
}

var IndexPortFlag = cli.IntFlag{
	Name:   "index-port",
	Usage:  "Index server port",
	Value:  6080,
	EnvVar: "FPSTORE_INDEX_PORT",
}

func PrepareFingerprintCache(c *cli.Context) (fpstore.FingerprintCache, error) {
	return fpstore.NewRedisFingerprintCache(&redis.Options{
		Addr:     net.JoinHostPort(c.String(RedisHostFlag.Name), strconv.Itoa(c.Int(RedisPortFlag.Name))),
		Password: c.String(RedisPasswordFlag.Name),
		DB:       c.Int(RedisDatabaseFlag.Name),
	}), nil
}

func PrepareFingerprintStore(c *cli.Context) (fpstore.FingerprintStore, error) {
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

	return fpstore.NewPostgresFingerprintStore(db), nil
}

func PrepareFingerprintIndex(c *cli.Context) (fpstore.FingerprintIndex, error) {
	addr := net.JoinHostPort(c.String(IndexHostFlag.Name), strconv.Itoa(c.Int(IndexPortFlag.Name)))
	conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, errors.WithMessage(err, "failed to connect to index server")
	}
	client := index_pb.NewIndexClient(conn)
	return fpstore.NewFingerprintIndexClient(client), nil
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

	service := fpstore.NewFingerprintStoreService(fingerprintStore, fingerprintIndex, fingerprintCache)

	listenAddr := net.JoinHostPort(c.String(ListenHostFlag.Name), strconv.Itoa(c.Int(ListenPortFlag.Name)))
	return fpstore.RunFingerprintStoreServer(listenAddr, service)
}

func CreateApp() *cli.App {
	app := cli.NewApp()
	app.Name = "fpstore"
	app.Usage = "AcoustID fingerprint store service"
	app.Flags = []cli.Flag{
		DebugFlag,
	}
	app.Commands = []cli.Command{
		{
			Name:  "server",
			Usage: "Runs fpstore service",
			Flags: []cli.Flag{
				ListenHostFlag,
				ListenPortFlag,
				PostgresHost,
				PostgresPort,
				PostgresUser,
				PostgresPassword,
				PostgresDatabase,
				RedisHostFlag,
				RedisPortFlag,
				RedisPasswordFlag,
				RedisDatabaseFlag,
				IndexHostFlag,
				IndexPortFlag,
			},
			Action: PrepareAndRunServer,
		},
	}
	return app
}

func main() {
	err := CreateApp().Run(os.Args)
	if err != nil {
		log.Fatal(err)
	}
}
