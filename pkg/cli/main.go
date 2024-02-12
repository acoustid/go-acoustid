package cli

import (
	"os"

	"github.com/acoustid/go-acoustid/pkg/fpstore"
	"github.com/acoustid/go-acoustid/pkg/index"
	"github.com/mattn/go-isatty"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/urfave/cli/v2"
)

var DebugFlag = cli.BoolFlag{
	Name:    "debug, d",
	Usage:   "enable debug mode",
	EnvVars: []string{"ASERVER_DEBUG"},
}

func Setup(c *cli.Context) error {
	zerolog.SetGlobalLevel(zerolog.InfoLevel)
	if c.Bool(DebugFlag.Name) {
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
	}

	if isatty.IsTerminal(os.Stdout.Fd()) {
		log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stdout})
	}

	return nil
}

func BuildApp() *cli.App {
	return &cli.App{
		Name:  "aserver",
		Usage: "AcoustID server",
		Flags: []cli.Flag{
			&DebugFlag,
		},
		Before: Setup,
		Commands: []*cli.Command{
			fpstore.BuildCli(),
			index.BuildCli(),
		},
	}
}

func Run() {
	app := BuildApp()
	if err := app.Run(os.Args); err != nil {
		log.Fatal().Err(err).Msg("App failed")
	}
}
