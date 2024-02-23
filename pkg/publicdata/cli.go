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

type storageFlags struct {
	Bucket          *cli.StringFlag
	Endpoint        *cli.StringFlag
	AccessKeyId     *cli.StringFlag
	SecretAccessKey *cli.StringFlag
}

func NewStorageFlags(prefix string, envPrefix string) *storageFlags {
	return &storageFlags{
		Bucket: &cli.StringFlag{
			Name:    prefix + "bucket",
			Usage:   "S3-compatible bucket",
			EnvVars: []string{envPrefix + "BUCKET"},
		},
		Endpoint: &cli.StringFlag{
			Name:    prefix + "endpoint",
			Usage:   "S3-compatible endpoint",
			EnvVars: []string{envPrefix + "ENDPOINT"},
		},
		AccessKeyId: &cli.StringFlag{
			Name:    prefix + "access-key-id",
			Usage:   "S3-compatible access key ID",
			EnvVars: []string{envPrefix + "ACCESS_KEY_ID"},
		},
		SecretAccessKey: &cli.StringFlag{
			Name:    prefix + "secret-access-key",
			Usage:   "S3-compatible secret access key",
			EnvVars: []string{envPrefix + "SECRET_ACCESS_KEY"},
		},
	}
}

func (f *storageFlags) Flags() []cli.Flag {
	return []cli.Flag{
		f.Bucket,
		f.Endpoint,
		f.AccessKeyId,
		f.SecretAccessKey,
	}
}

func (f *storageFlags) Connect(c *cli.Context) (*minio.Client, string, error) {
	client, err := minio.New(f.Endpoint.Get(c), &minio.Options{
		Creds:  credentials.NewStaticV4(f.AccessKeyId.Get(c), f.SecretAccessKey.Get(c), ""),
		Secure: true,
	})
	if err != nil {
		return nil, "", errors.WithMessage(err, "failed to connect to storage")
	}

	bucket := f.Bucket.Get(c)

	return client, bucket, nil
}

func RunExport(c *cli.Context, db *sql.DB, storage *minio.Client, bucket string) error {
	log.Info().Msg("Running export")
	return nil
}

func NewExportCommand() *cli.Command {
	dbFlags := common.NewDatabaseCliFlags("postgres-", "ACOUSTID_EXPORT_POSTGRES_")
	storageFlags := NewStorageFlags("storage-", "ACOUSTID_EXPORT_STORAGE_")
	cmd := &cli.Command{
		Name:  "export",
		Usage: "Export public data",
		Flags: common.ConcatFlags(dbFlags.Flags(), storageFlags.Flags()),
		Action: func(c *cli.Context) error {
			db, err := dbFlags.Config(c).Connect()
			if err != nil {
				return errors.WithMessage(err, "failed to connect to database")
			}
			defer db.Close()

			storage, bucket, err := storageFlags.Connect(c)
			if err != nil {
				return err
			}

			return RunExport(c, db, storage, bucket)
		},
	}
	return cmd
}

func BuildCli() *cli.Command {
	return &cli.Command{
		Name:  "publicdata",
		Usage: "AcoustID public data managemenr",
		Subcommands: []*cli.Command{
			NewExportCommand(),
		},
	}
}
