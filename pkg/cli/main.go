package cli

import (
	"os"

	"github.com/acoustid/go-acoustid/pkg/fpindex"
	"github.com/acoustid/go-acoustid/pkg/fpstore"
	"github.com/mattn/go-isatty"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/urfave/cli/v2"
)

var verboseFlag = &cli.BoolFlag{
	Name:    "verbose",
	Aliases: []string{"v"},
	Usage:   "enable verbose mode",
	EnvVars: []string{"ASERVER_VERBOSE"},
}

var logLevelFlag = &cli.StringFlag{
	Name:    "log-level",
	Usage:   "logging level",
	EnvVars: []string{"ASERVER_LOG_LEVEL"},
}

func Setup(c *cli.Context) error {
	if c.IsSet(logLevelFlag.Name) {
		logLevel, err := zerolog.ParseLevel(c.String(logLevelFlag.Name))
		if err != nil {
			return err
		}
		zerolog.SetGlobalLevel(logLevel)
	} else {
		switch verbosity := c.Count(verboseFlag.Name); verbosity {
		case 0:
			zerolog.SetGlobalLevel(zerolog.WarnLevel)
		case 1:
			zerolog.SetGlobalLevel(zerolog.InfoLevel)
		case 2:
			zerolog.SetGlobalLevel(zerolog.DebugLevel)
		default:
			zerolog.SetGlobalLevel(zerolog.TraceLevel)
		}
	}

	if isatty.IsTerminal(os.Stdout.Fd()) {
		log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stdout})
	}

	zerolog.DefaultContextLogger = &log.Logger

	return nil
}

func BuildApp() *cli.App {
	return &cli.App{
		Name:  "aserver",
		Usage: "AcoustID server",
		Flags: []cli.Flag{
			verboseFlag,
			logLevelFlag,
		},
		Before: Setup,
		Commands: []*cli.Command{
			fpstore.BuildCli(),
			fpindex.BuildCli(),
		},
	}
}

func Run() {
	app := BuildApp()
	if err := app.Run(os.Args); err != nil {
		log.Fatal().Err(err).Msg("App failed")
	}
}
