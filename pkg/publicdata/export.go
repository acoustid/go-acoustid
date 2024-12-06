package publicdata

import (
	"bytes"
	"compress/gzip"
	"context"
	"database/sql"
	"fmt"
	"io"
	"os"
	"strings"
	"text/template"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/rs/zerolog/log"
)

type exporterTableInfo struct {
	name  string
	query string
	delta bool
}

type exporter struct {
	db         *sql.DB
	storage    *minio.Client
	bucketName string
	tables     []exporterTableInfo
}

func (ex *exporter) AddTable(name string, query string, delta bool) {
	ex.tables = append(ex.tables, exporterTableInfo{name: name, query: query, delta: delta})
}

func (ex *exporter) RenderQueryTemplate(queryTmpl string, startTime, endTime time.Time) (string, error) {
	tmplCtx := QueryContext{
		StartTime: startTime.Format(time.RFC3339),
		EndTime:   endTime.Format(time.RFC3339),
	}

	tmpl, err := template.New("query").Parse(queryTmpl)
	if err != nil {
		return "", err
	}

	var buf bytes.Buffer
	err = tmpl.Execute(&buf, &tmplCtx)
	if err != nil {
		return "", err
	}

	return buf.String(), nil
}

func (ex *exporter) ExportQuery(ctx context.Context, path string, query string) error {
	tmpFile, err := os.CreateTemp("", "export")
	if err != nil {
		return err
	}
	defer os.Remove(tmpFile.Name())

	gzipFile := gzip.NewWriter(tmpFile)

	wrappedQuery := fmt.Sprintf("SELECT convert_to(json_strip_nulls(row_to_json(r))::text, 'UTF8') FROM (%s) r", query)
	rows, err := ex.db.QueryContext(ctx, wrappedQuery)
	if err != nil {
		return err
	}
	for rows.Next() {
		var row []byte
		err := rows.Scan(&row)
		if err != nil {
			return err
		}
		_, err = gzipFile.Write(row)
		if err != nil {
			return err
		}
		_, err = gzipFile.Write([]byte("\n"))
		if err != nil {
			return err
		}
	}

	err = gzipFile.Close()
	if err != nil {
		return err
	}

	size, err := tmpFile.Seek(0, io.SeekCurrent)
	if err != nil {
		return err
	}

	_, err = tmpFile.Seek(0, io.SeekStart)
	if err != nil {
		return err
	}

	_, err = ex.storage.PutObject(ctx, ex.bucketName, path, tmpFile, size, minio.PutObjectOptions{
		ContentType: "application/gzip",
	})
	if err != nil {
		return err
	}

	err = tmpFile.Close()
	if err != nil {
		return err
	}

	return nil
}

func (ex *exporter) ExportDeltaFile(ctx context.Context, path string, name string, queryTmpl string, startTime, endTime time.Time) error {
	logger := log.With().Str("table", name).Str("date", startTime.Format("2006-01-02")).Logger()

	logger.Info().Msgf("Exporting data file")

	query, err := ex.RenderQueryTemplate(queryTmpl, startTime, endTime)
	if err != nil {
		logger.Error().Err(err).Msg("Failed to render query template")
		return err
	}

	err = ex.ExportQuery(ctx, path, query)
	if err != nil {
		logger.Error().Err(err).Msg("Failed to export query")
		return err
	}
	return nil
}

func addFolder(changedFolders map[string]struct{}, folder string) {
	for {
		changedFolders[folder+"/"] = struct{}{}
		i := strings.LastIndexByte(folder, '/')
		if i == -1 {
			break
		}
		folder = folder[:i]
	}
	changedFolders[""] = struct{}{}
}

func (ex *exporter) ExportDeltaFiles(ctx context.Context, startTime, endTime time.Time, changedFolders map[string]struct{}) error {
	log.Info().Str("date", startTime.Format("2006-01-02")).Msgf("Exporting data files")

	directory := startTime.Format("2006/2006-01")
	prefix := directory + startTime.Format("/2006-01-02-")
	objects := ex.storage.ListObjects(ctx, ex.bucketName, minio.ListObjectsOptions{
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

	for _, table := range ex.tables {
		if !table.delta {
			continue
		}
		key := table.name + ".jsonl.gz"
		if _, ok := foundKeys[key]; ok {
			continue
		}
		err := ex.ExportDeltaFile(ctx, prefix+key, table.name, table.query, startTime, endTime)
		if err != nil {
			return err
		}
		addFolder(changedFolders, directory)
	}

	return nil
}

func (ex *exporter) CreateBucket(ctx context.Context) error {
	exists, err := ex.storage.BucketExists(ctx, ex.bucketName)
	if err != nil {
		return err
	}
	if exists {
		return nil
	}
	return ex.storage.MakeBucket(ctx, ex.bucketName, minio.MakeBucketOptions{})
}

func (ex *exporter) Run(ctx context.Context) error {
	ex.CreateBucket(ctx)

	changedFolders := make(map[string]struct{})

	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	var maxDays = 7
	if today.Day() == 1 {
		maxDays = 32
	}

	endTime := today
	for i := 0; i < maxDays; i++ {
		startTime := endTime.AddDate(0, 0, -1)
		err := ex.ExportDeltaFiles(ctx, startTime, endTime, changedFolders)
		if err != nil {
			return err
		}
		endTime = startTime
	}

	idx := indexer{storage: ex.storage, bucketName: ex.bucketName}
	for folder := range changedFolders {
		err := idx.UpdateIndexFile(ctx, folder, false)
		if err != nil {
			return err
		}
	}

	return nil
}

func ExportDataFiles(ctx context.Context, storage *minio.Client, bucketName string, db *sql.DB) error {
	ex := &exporter{db: db, storage: storage, bucketName: bucketName}
	ex.AddTable("fingerprint-update", ExportFingerprintUpdateQuery, true)
	ex.AddTable("meta-update", ExportMetaUpdateQuery, true)
	ex.AddTable("track-update", ExportTrackUpdateQuery, true)
	ex.AddTable("track_fingerprint-update", ExportTrackFingerprintUpdateQuery, true)
	ex.AddTable("track_mbid-update", ExportTrackMbidUpdateQuery, true)
	ex.AddTable("track_puid-update", ExportTrackPuidUpdateQuery, true)
	ex.AddTable("track_meta-update", ExportTrackMetaUpdateQuery, true)
	return ex.Run(ctx)
}
