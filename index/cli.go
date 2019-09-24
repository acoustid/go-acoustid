package index

import (
	"os"

	"github.com/urfave/cli"
	log "github.com/sirupsen/logrus"
)

var DebugFlag = cli.BoolFlag{
	Name: "debug, d",
	Usage: "enable debug mode",
	EnvVar: "ACOUSTID_DEBUG",
}

var IndexHostFlag = cli.StringFlag{
	Name: "index-host",
	Usage: "index server hostname",
	Value: "localhost",
	EnvVar: "ACOUSTID_INDEX_HOST",
}

var IndexPortFlag = cli.IntFlag{
	Name: "index-port",
	Usage: "index server port number",
	Value: 6080,
	EnvVar: "ACOUSTID_INDEX_PORT",
}

var DatabaseNameFlag = cli.StringFlag{
	Name: "database-name",
	Usage: "database name",
	Value: "acoustid",
	EnvVar: "ACOUSTID_DATABASE_NAME",
}

var DatabaseHostFlag = cli.StringFlag{
	Name: "database-host",
	Usage: "database server hostname",
	Value: "localhost",
	EnvVar: "ACOUSTID_DATABASE_HOST",
}

var DatabasePortFlag = cli.IntFlag{
	Name: "database-port",
	Usage: "database server port",
	Value: 5432,
	EnvVar: "ACOUSTID_DATABASE_PORT",
}

func PrepareAndRunUpdater(c *cli.Context) error {
	cfg := NewUpdaterConfig()

	cfg.Debug = c.Bool("debug")

	cfg.Index.Host = c.String("index-host")
	cfg.Index.Port = c.Int("index-port")

	cfg.Database.Name = c.String("database-name")
	cfg.Database.Host = c.String("database-host")
	cfg.Database.Port = c.Int("database-port")

	RunUpdater(cfg)
	return nil
}

func CreateApp() *cli.App {
	app := cli.NewApp()
	app.Name = "aindex"
	app.Usage = "AcoustID index tools"
	app.Flags = []cli.Flag{
		DebugFlag,
	}
	app.Commands = []cli.Command{
		{
			Name: "updater",
			Usage: "Runs AcoustID index updater",
			Flags: []cli.Flag{
				IndexHostFlag,
				IndexPortFlag,
				DatabaseNameFlag,
				DatabaseHostFlag,
				DatabasePortFlag,
			},
			Action: PrepareAndRunUpdater,
		},
	}
	return app
}

func Main() {
	err := CreateApp().Run(os.Args)
	if err != nil {
		log.Fatal(err)
	}
}
