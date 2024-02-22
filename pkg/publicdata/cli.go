package publicdata

import (
	"database/sql"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/rs/zerolog/log"

	"github.com/acoustid/go-acoustid/common"
	"github.com/pkg/errors"
	"github.com/urfave/cli/v2"
)

var PostgresHost = cli.StringFlag{
	Name:    "postgres-host",
	Usage:   "Postgres server address",
	Value:   "localhost",
	EnvVars: []string{"ACOUSTID_EXPORT_POSTGRES_HOST"},
}

var PostgresPort = cli.IntFlag{
	Name:    "postgres-port",
	Usage:   "Postgres server port",
	Value:   5432,
	EnvVars: []string{"ACOUSTID_EXPORT_POSTGRES_PORT"},
}

var PostgresUser = cli.StringFlag{
	Name:    "postgres-user",
	Usage:   "Postgres server user",
	Value:   "acoustid",
	EnvVars: []string{"ACOUSTID_EXPORT_POSTGRES_USER"},
}

var PostgresPassword = cli.StringFlag{
	Name:    "postgres-password",
	Usage:   "Postgres server password",
	Value:   "",
	EnvVars: []string{"ACOUSTID_EXPORT_POSTGRES_PASSWORD"},
}

var PostgresDatabase = cli.StringFlag{
	Name:    "postgres-database",
	Usage:   "Postgres server database",
	Value:   "acoustid",
	EnvVars: []string{"ACOUSTID_EXPORT_POSTGRES_DATABASE"},
}

var StorageBucket = cli.StringFlag{
	Name:     "storage-bucket",
	Usage:    "S3-compatible bucket",
	EnvVars:  []string{"ACOUSTID_EXPORT_STORAGE_BUCKET"},
	Required: true,
}

var StorageEndpoint = cli.StringFlag{
	Name:     "storage-endpoint",
	Usage:    "S3-compatible endpoint",
	EnvVars:  []string{"ACOUSTID_EXPORT_STORAGE_ENDPOINT"},
	Required: true,
}

var StorageAccessKeyId = cli.StringFlag{
	Name:    "storage-access-key-id",
	Usage:   "S3-compatible access key ID",
	EnvVars: []string{"ACOUSTID_EXPORT_STORAGE_ACCESS_KEY_ID"},
}

var StorageSecretAccessKey = cli.StringFlag{
	Name:    "storage-secret-access-key",
	Usage:   "S3-compatible secret access key",
	EnvVars: []string{"ACOUSTID_EXPORT_STORAGE_SECRET_ACCESS_KEY"},
}

func ConnectToPostgres(c *cli.Context) (*sql.DB, error) {
	var config common.DatabaseConfig
	config.Host = c.String(PostgresHost.Name)
	config.Port = c.Int(PostgresPort.Name)
	config.User = c.String(PostgresUser.Name)
	config.Password = c.String(PostgresPassword.Name)
	config.Database = c.String(PostgresDatabase.Name)

	db, err := config.Connect()
	if err != nil {
		return nil, errors.WithMessage(err, "failed to connect to database")
	}

	return db, nil
}

func ConnectToStorage(c *cli.Context) (*minio.Client, error) {
	client, err := minio.New(StorageEndpoint.Get(c), &minio.Options{
		Creds:  credentials.NewStaticV4(StorageAccessKeyId.Get(c), StorageSecretAccessKey.Get(c), ""),
		Secure: true,
	})
	if err != nil {
		return nil, errors.WithMessage(err, "failed to connect to storage")
	}

	return client, nil
}

func RunExport(c *cli.Context) error {
	db, err := ConnectToPostgres(c)
	if err != nil {
		return err
	}

	defer db.Close()

	storage, err := ConnectToStorage(c)
	if err != nil {
		return err
	}

	_ = storage

	log.Info().Msg("Running export")
	return nil
}

func BuildCli() *cli.Command {
	exportCommand := &cli.Command{
		Name:  "export",
		Usage: "Export public data",
		Flags: []cli.Flag{
			&PostgresHost,
			&PostgresPort,
			&PostgresUser,
			&PostgresPassword,
			&PostgresDatabase,
			&StorageBucket,
			&StorageEndpoint,
			&StorageAccessKeyId,
			&StorageSecretAccessKey,
		},
		Action: RunExport,
	}

	return &cli.Command{
		Name:  "publicdata",
		Usage: "AcoustID public data managemenr",
		Subcommands: []*cli.Command{
			exportCommand,
		},
	}
}
