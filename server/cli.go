package server

import (
	"github.com/urfave/cli"
)

func RunServerCommand(c *cli.Context) error {
	return nil
}

var ServerCommand = cli.Command{
	Name:   "server",
	Usage:  "Runs updater",
	Action: RunServerCommand,
}
