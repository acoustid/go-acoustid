package main

import (
	"database/sql"
	"os"

	_ "github.com/lib/pq"
	"github.com/pkg/errors"

	"github.com/acoustid/go-acoustid/fpstore"
	"github.com/redis/go-redis/v9"
	log "github.com/sirupsen/logrus"
	"github.com/urfave/cli"
)

var DebugFlag = cli.BoolFlag{
	Name:   "debug, d",
	Usage:  "enable debug mode",
	EnvVar: "FPSTORE_DEBUG",
}

var RedisAddrFlag = cli.StringFlag{
	Name:   "redis-addr",
	Usage:  "Redis server address",
	Value:  "localhost:6379",
	EnvVar: "FPSTORE_REDIS_ADDR",
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

var ListenAddrFlag = cli.StringFlag{
	Name:  "listen-addr",
	Usage: "Listen address",
	Value: "localhost:4659",
}

func PrepareFingerprintCache(c *cli.Context) (fpstore.FingerprintCache, error) {
	return fpstore.NewRedisFingerprintCache(&redis.Options{
		Addr:     c.String(RedisAddrFlag.Name),
		Password: c.String(RedisPasswordFlag.Name),
		DB:       c.Int(RedisDatabaseFlag.Name),
	}), nil
}

func PrepareFingerprintStore(c *cli.Context) (fpstore.FingerprintStore, error) {
	connStr := ""
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, err
	}
	return fpstore.NewSqlFingerprintStore(db), nil
}

func PrepareAndRunServer(c *cli.Context) error {
	fingerprintCache, err := PrepareFingerprintCache(c)
	if err != nil {
		return errors.WithMessage(err, "failed to initialize fingerprint cache")
	}

	fingerprintStore, err := PrepareFingerprintStore(c)
	if err != nil {
		return errors.WithMessage(err, "failed to initialize fingerprint store")
	}

	service := fpstore.NewFingerprintStoreService(fingerprintStore, fingerprintCache)

	return fpstore.RunFingerprintStoreServer(c.String(ListenAddrFlag.Name), service)
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
				ListenAddrFlag,
				RedisAddrFlag,
				RedisPasswordFlag,
				RedisDatabaseFlag,
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
