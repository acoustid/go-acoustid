package publicdata

import (
	"context"
	"database/sql"
	"strings"
	"time"

	"github.com/minio/minio-go/v7"
)

type Exporter struct {
	storage    *minio.Client
	bucketName string
	db         *sql.DB
}

func NewExporter(storage *minio.Client, bucketName string, db *sql.DB) *Exporter {
	return &Exporter{
		storage:    storage,
		bucketName: bucketName,
		db:         db,
	}
}

func (e *Exporter) ExportDay(ctx context.Context, day time.Time) error {
	prefix := day.Format("2006/01") + "/" + day.Format("2006-01-02") + "-"
	objects := e.storage.ListObjects(ctx, e.bucketName, minio.ListObjectsOptions{
		Prefix: prefix,
	})
	foundKeys := make(map[string]struct{})
	for object := range objects {
		if object.Err != nil {
			return object.Err
		}
		key := strings.TrimPrefix(object.Key, prefix)
		foundKeys[key] = struct{}{}
	}
	return nil
}

func (e *Exporter) ExportLastDays(ctx context.Context, numDays int) error {
	today := time.Now().UTC()
	for i := 0; i < numDays; i++ {
		err := e.ExportDay(ctx, today.AddDate(0, 0, -i))
		if err != nil {
			return err
		}
	}
	return nil

}
