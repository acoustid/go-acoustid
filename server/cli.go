package server

import (
	"database/sql"
	"fmt"
	"log"
	"net"
	"os"
	"strconv"

	"github.com/acoustid/go-acoustid/database/fingerprint_db"
	index "github.com/acoustid/go-acoustid/pkg/fpindex"
	"github.com/acoustid/go-acoustid/server/api"
	"github.com/acoustid/go-acoustid/server/services/legacy"
	_ "github.com/lib/pq"
	"github.com/urfave/cli/v2"
)

var DebugFlag = cli.BoolFlag{
	Name:    "debug, d",
	Usage:   "enable debug mode",
	EnvVars: []string{"ACOUSTID_DEBUG"},
}

func RunApiCommand(c *cli.Context) error {
	api := api.NewAPI()

	indexAddr := c.String("index-address")
	host, portStr, err := net.SplitHostPort(indexAddr)
	if err != nil {
		return fmt.Errorf("failed to parse index-address: %w", err)
	}
	port, err := strconv.Atoi(portStr)
	if err != nil {
		return fmt.Errorf("failed to parse index-address: %w", err)
	}
	indexConfig := index.NewIndexConfig()
	indexConfig.Host = host
	indexConfig.Port = port
	indexClientPool := index.NewIndexClientPool(indexConfig, 100)

	db, err := sql.Open("postgres", c.String("fingerprint-db-url"))
	if err != nil {
		return fmt.Errorf("failed to connect to fingerprint database: %w", err)
	}
	defer db.Close()

	fingerprintDB := fingerprint_db.NewFingerprintDB(db)

	api.FingerprintSearcher = legacy.NewFingerprintSearcher(indexClientPool, fingerprintDB)
	return api.ListenAndServe(c.String("listen"))
}

var ApiCommand = &cli.Command{
	Name:   "api",
	Usage:  "Runs API server",
	Action: RunApiCommand,
	Flags: []cli.Flag{
		&cli.StringFlag{
			Name:    "listen, l",
			Usage:   "listen address",
			EnvVars: []string{"ACOUSTID_API_LISTEN_ADDRESS"},
			Value:   "127.0.0.1:8080",
		},
		&cli.StringFlag{
			Name:    "index-address",
			Usage:   "index address",
			EnvVars: []string{"ACOUSTID_API_INDEX_ADDRESS"},
			Value:   "127.0.0.1:6080",
		},
		&cli.StringFlag{
			Name:    "fingerprint-db-url",
			Usage:   "fingerprint database URL",
			EnvVars: []string{"ACOUSTID_API_FINGERPRINT_DB_URL"},
			Value:   "postgresql://127.0.0.1:5432/acoustid",
		},
	},
}

func CreateApp() *cli.App {
	app := cli.NewApp()
	app.Name = "aserver"
	app.Usage = "AcoustID server"
	app.Flags = []cli.Flag{
		&DebugFlag,
	}
	app.Commands = []*cli.Command{
		ApiCommand,
	}
	return app
}

func Main() {
	err := CreateApp().Run(os.Args)
	if err != nil {
		log.Fatal(err)
	}
}
