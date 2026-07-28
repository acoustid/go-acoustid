package common

import "testing"

func TestURLSSLMode(t *testing.T) {
	cases := []struct {
		name     string
		mode     string
		rootCert string
		want     string
	}{
		{"default is unchanged", "", "", "postgresql://u:p@h:5432/db?sslmode=disable"},
		{"explicit disable", "disable", "", "postgresql://u:p@h:5432/db?sslmode=disable"},
		{"require", "require", "", "postgresql://u:p@h:5432/db?sslmode=require"},
		{"verify-full with a CA", "verify-full", "/etc/ssl/ca.pem",
			"postgresql://u:p@h:5432/db?sslmode=verify-full&sslrootcert=%2Fetc%2Fssl%2Fca.pem"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			cfg := &DatabaseConfig{
				Database: "db", Host: "h", Port: 5432, User: "u", Password: "p",
				SSLMode: tc.mode, SSLRootCert: tc.rootCert,
			}
			if got := cfg.URL().String(); got != tc.want {
				t.Errorf("got  %s\nwant %s", got, tc.want)
			}
		})
	}
}
