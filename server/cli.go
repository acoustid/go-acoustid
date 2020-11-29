package server

import (
	"github.com/urfave/cli"
	"log"
	"os"
)

var DebugFlag = cli.BoolFlag{
	Name:   "debug, d",
	Usage:  "enable debug mode",
	EnvVar: "ACOUSTID_DEBUG",
}

func RunApiCommand(c *cli.Context) error {
	return RunWebService()
}

var ApiCommand = cli.Command{
	Name:   "api",
	Usage:  "Runs API server",
	Action: RunApiCommand,
}

func CreateApp() *cli.App {
	app := cli.NewApp()
	app.Name = "aserver"
	app.Usage = "AcoustID server"
	app.Flags = []cli.Flag{
		DebugFlag,
	}
	app.Commands = []cli.Command{
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
