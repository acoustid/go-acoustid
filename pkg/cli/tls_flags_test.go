package cli

import (
	"strings"
	"testing"

	"github.com/urfave/cli/v2"
)

// Every command that opens a Postgres connection must expose the TLS options.
// Without this, an operator can set them fleet-wide and have one binary
// silently keep connecting in cleartext -- which is how the fpindex updater
// was missed when TLS support was first added.
func TestDatabaseCommandsExposeTLSFlags(t *testing.T) {
	app := BuildApp()

	var walk func(prefix string, cmd *cli.Command)
	checked := 0

	walk = func(prefix string, cmd *cli.Command) {
		for _, sub := range cmd.Subcommands {
			walk(strings.TrimSpace(prefix+" "+cmd.Name), sub)
		}
		if len(cmd.Subcommands) > 0 {
			return
		}

		names := map[string]bool{}
		for _, flag := range cmd.Flags {
			for _, name := range flag.Names() {
				names[name] = true
			}
		}

		// Identify database-using commands by the host flag they already have.
		var sslMode, sslRootCert string
		switch {
		case names["postgres-host"]:
			sslMode, sslRootCert = "postgres-sslmode", "postgres-sslrootcert"
		case names["database-host"]:
			sslMode, sslRootCert = "database-sslmode", "database-sslrootcert"
		default:
			return
		}

		checked++
		full := strings.TrimSpace(prefix + " " + cmd.Name)
		if !names[sslMode] {
			t.Errorf("%s connects to Postgres but has no --%s", full, sslMode)
		}
		if !names[sslRootCert] {
			t.Errorf("%s connects to Postgres but has no --%s", full, sslRootCert)
		}
	}

	for _, cmd := range app.Commands {
		walk("", cmd)
	}

	if checked == 0 {
		t.Fatal("found no database-using commands; the test is not looking at anything")
	}
	t.Logf("checked %d database-using commands", checked)
}
