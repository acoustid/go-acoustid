package cli

import (
	"log"
	"os"

	"github.com/acoustid/go-acoustid/pkg/fpstore"
	"github.com/urfave/cli/v2"
)

func BuildApp() *cli.App {
	return &cli.App{
		Name:  "aserver",
		Usage: "AcoustID server",
		Commands: []*cli.Command{
			fpstore.BuildCli(),
		},
	}
}

func Run() {
	app := BuildApp()
	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}
