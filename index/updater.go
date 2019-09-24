package index

import (
	"context"
	"database/sql"
	"time"

	log "github.com/sirupsen/logrus"
	"github.com/lib/pq"
)

const UpdateBatchSize = 1000

type FingerprintStore struct {
	db *sql.DB
}

func NewFingerprintStore(db *sql.DB) *FingerprintStore {
	return &FingerprintStore{
		db: db,
	}
}

func (s *FingerprintStore) GetMaxID(ctx context.Context) (int, error) {
	row := s.db.QueryRowContext(ctx, "SELECT max(id) FROM fingerprint")
	var id int
	err := row.Scan(&id)
	if err != nil {
		if err == sql.ErrNoRows {
			return 0, nil
		}
		return 0, err
	}
	return id, nil
}

func (s *FingerprintStore) GetNextFingerprints(ctx context.Context, lastID uint32, limit int) ([]FingerprintInfo, error) {
	rows, err := s.db.QueryContext(ctx, "SELECT id, acoustid_extract_query(fingerprint) FROM fingerprint WHERE id > $1 ORDER BY id LIMIT $2", lastID, limit)
	if err != nil {
		return nil, err
	}
	var fingerprints []FingerprintInfo
	for rows.Next() {
		var id uint32
		var hashes []uint32
		err = rows.Scan(&id, pq.Array(hashes))
		if err != nil {
			return nil, err
		}
		fingerprints = append(fingerprints, FingerprintInfo{ID: id, Hashes: hashes})
	}
	err = rows.Close()
	if err != nil {
		return nil, err
	}
	return fingerprints, nil
}

type UpdaterConfig struct {
	Database *DatabaseConfig
	Index    *IndexConfig
	Debug bool
}

func NewUpdaterConfig() *UpdaterConfig {
	return &UpdaterConfig{
		Database: NewDatabaseConfig(),
		Index:    NewIndexConfig(),
	}
}

func RunUpdater(cfg *UpdaterConfig) {
	if cfg.Debug {
		log.SetLevel(log.DebugLevel)
	} else {
		log.SetLevel(log.InfoLevel)
	}

	db, err := sql.Open("postgres", cfg.Database.URL().String())
	if err != nil {
		log.Fatalf("Failed to connect to database: %s", err)
	}
	defer db.Close()

	idx, err := ConnectWithConfig(context.Background(), cfg.Index)
	if err != nil {
		log.Fatalf("Failed to connect to index: %s", err)
	}
	defer idx.Close(context.Background())

	fp := NewFingerprintStore(db)

	for {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()

		lastID, err := GetLastFingerprintID(ctx, idx)
		if err != nil {
			log.Fatalf("Failed to get the last fingerprint ID in index: %s", err)
		}

		fingerprints, err := fp.GetNextFingerprints(ctx, lastID, UpdateBatchSize)
		MultiInsert(ctx, idx, fingerprints)

		fingerprintCount := len(fingerprints)
		log.Infof("Added %d fingerprints up to ID %d", fingerprintCount, fingerprints[fingerprintCount-1].ID)

		if fingerprintCount == 0 {
			delay := 100 * time.Millisecond
			time.Sleep(delay)
			log.Debugf("Sleeping for %v", delay)
		}
	}
}
