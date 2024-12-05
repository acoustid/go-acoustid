package publicdata

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/rs/zerolog/log"
)

type indexer struct {
	storage    *minio.Client
	bucketName string
	db         *sql.DB
}

func NewExporter(storage *minio.Client, bucketName string, db *sql.DB) *indexer {
	return &indexer{
		storage:    storage,
		bucketName: bucketName,
		db:         db,
	}
}

type fileInfo struct {
	name string `json:"name"`
	size int64  `json:"size,omitempty"`
}

func (e *indexer) UpdateIndexFile(ctx context.Context, prefix string, recursive bool) error {
	objects := e.storage.ListObjects(ctx, e.bucketName, minio.ListObjectsOptions{
		Prefix:    prefix,
		Recursive: false,
	})

	var sb strings.Builder
	sb.WriteString("<!DOCTYPE html>\n")
	sb.WriteString("<html>\n")
	sb.WriteString("<head><title>Index of /")
	sb.WriteString(strings.TrimRight(prefix, "/"))
	sb.WriteString("</title></head>\n")
	sb.WriteString("<body>\n")
	sb.WriteString("<h1>Index of /")
	sb.WriteString(strings.TrimRight(prefix, "/"))
	sb.WriteString("</h1>\n")
	sb.WriteString("<ul>\n")

	files := make([]fileInfo, 0)

	for obj := range objects {
		if obj.Key == "/" {
			continue
		}
		name := strings.TrimPrefix(obj.Key, prefix)
		if strings.HasPrefix(name, "index.") {
			continue
		}
		sb.WriteString("<li><a href=\"")
		sb.WriteString(name)
		sb.WriteString("\">")
		sb.WriteString(name)
		sb.WriteString("</a>")
		if obj.Size > 0 {
			size := float64(obj.Size)
			unit := " B"
			if size > 1024 {
				size /= 1024
				unit = " KB"
			}
			if size > 1024 {
				size /= 1024
				unit = " MB"
			}
			if size > 1024 {
				size /= 1024
				unit = " GB"
			}
			sb.WriteString(fmt.Sprintf(" (%.1f%s)", size, unit))
		}
		sb.WriteString("</li>\n")
		if strings.HasSuffix(obj.Key, "/") && recursive {
			e.UpdateIndexFile(ctx, obj.Key, recursive)
		}
		files = append(files, fileInfo{name: name, size: obj.Size})
	}

	sb.WriteString("<li><a href=\"index.html\">index.html</a></li>\n")
	sb.WriteString("<li><a href=\"index.json\">index.json</a></li>\n")

	sb.WriteString("</ul>\n")
	sb.WriteString("</body>\n")
	sb.WriteString("</html>")

	reader := strings.NewReader(sb.String())
	log.Info().Msgf("Writing index.html to %s/%s", e.bucketName, prefix+"index.html")
	_, err := e.storage.PutObject(ctx, e.bucketName, prefix+"index.html", reader, int64(sb.Len()), minio.PutObjectOptions{
		ContentType: "text/html",
	})
	if err != nil {
		return err
	}

	jsonString, err := json.Marshal(files)
	if err != nil {
		return err
	}
	jsonReader := bytes.NewReader(jsonString)
	log.Info().Msgf("Writing index.json to %s/%s", e.bucketName, prefix+"index.json")
	_, err = e.storage.PutObject(ctx, e.bucketName, prefix+"index.json", jsonReader, int64(len(jsonString)), minio.PutObjectOptions{
		ContentType: "application/json",
	})
	return err
}

func (e *indexer) ExportDay(ctx context.Context, day time.Time, changedFolders map[string]struct{}) error {
	folder := day.Format("2006/2006-01")
	prefix := folder + "/" + day.Format("2006-01-02") + "-"
	log.Info().Msgf("Exporting data for %s", day.Format("2006-01-02"))
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
	addFolder(changedFolders, folder)
	return nil
}

func (e *indexer) ExportLastDays(ctx context.Context, numDays int) error {
	changedFolders := make(map[string]struct{})
	date := time.Now().UTC()
	for i := 0; i < numDays; i++ {
		err := e.ExportDay(ctx, date, changedFolders)
		if err != nil {
			return err
		}
		date = date.AddDate(0, 0, -1)
	}
	for folder := range changedFolders {
		err := e.UpdateIndexFile(ctx, folder, false)
		if err != nil {
			return err
		}
	}
	return nil

}

func UpdateIndexFiles(ctx context.Context, storage *minio.Client, bucketName string) error {
	idx := indexer{storage: storage, bucketName: bucketName}
	return idx.UpdateIndexFile(ctx, "", true)
}
