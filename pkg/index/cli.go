package index

import (
	"github.com/urfave/cli/v2"
)

var IndexHostFlag = cli.StringFlag{
	Name:    "index-host",
	Usage:   "index server hostname",
	Value:   "localhost",
	EnvVars: []string{"ACOUSTID_INDEX_HOST"},
}

var IndexPortFlag = cli.IntFlag{
	Name:    "index-port",
	Usage:   "index server port number",
	Value:   6080,
	EnvVars: []string{"ACOUSTID_INDEX_PORT"},
}

var DatabaseNameFlag = cli.StringFlag{
	Name:    "database-name",
	Usage:   "database name",
	Value:   "acoustid",
	EnvVars: []string{"ACOUSTID_DATABASE_NAME"},
}

var DatabaseHostFlag = cli.StringFlag{
	Name:    "database-host",
	Usage:   "database server hostname",
	Value:   "localhost",
	EnvVars: []string{"ACOUSTID_DATABASE_HOST"},
}

var DatabasePortFlag = cli.IntFlag{
	Name:    "database-port",
	Usage:   "database server port",
	Value:   5432,
	EnvVars: []string{"ACOUSTID_DATABASE_PORT"},
}

var DatabaseUsernameFlag = cli.StringFlag{
	Name:    "database-username",
	Usage:   "database user name",
	Value:   "acoustid",
	EnvVars: []string{"ACOUSTID_DATABASE_USERNAME"},
}

var DatabasePasswordFlag = cli.StringFlag{
	Name:    "database-password",
	Usage:   "database user password",
	Value:   "",
	EnvVars: []string{"ACOUSTID_DATABASE_PASSWORD"},
}

func PrepareAndRunUpdater(c *cli.Context) error {
	cfg := NewUpdaterConfig()

	cfg.Debug = c.Bool("debug")

	cfg.Index.Host = c.String("index-host")
	cfg.Index.Port = c.Int("index-port")

	cfg.Database.Database = c.String("database-name")
	cfg.Database.Host = c.String("database-host")
	cfg.Database.Port = c.Int("database-port")
	cfg.Database.User = c.String("database-username")
	cfg.Database.Password = c.String("database-password")

	RunUpdater(cfg)
	return nil
}

var UpdaterCommand = &cli.Command{
	Name:  "updater",
	Usage: "Runs fpstore gRPC service",
	Flags: []cli.Flag{
		&IndexHostFlag,
		&IndexPortFlag,
		&DatabaseNameFlag,
		&DatabaseHostFlag,
		&DatabasePortFlag,
		&DatabaseUsernameFlag,
		&DatabasePasswordFlag,
	},
	Action: PrepareAndRunUpdater,
}

func BuildCli() *cli.Command {
	return &cli.Command{
		Name:  "fpindex",
		Usage: "AcoustID fingerprint index tools",
		Subcommands: []*cli.Command{
			UpdaterCommand,
			ProxyCommand,
		},
	}
}
