package index

import (
	"context"
	"database/sql"
	"time"

    _ "github.com/lib/pq"
	log "github.com/sirupsen/logrus"
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
	rows, err := s.db.QueryContext(ctx, "SELECT id, acoustid_extract_query(fingerprint)::text FROM fingerprint WHERE id > $1 ORDER BY id LIMIT $2", lastID, limit)
	if err != nil {
		return nil, err
	}
	var fingerprints []FingerprintInfo
	for rows.Next() {
		var id uint32
		var encodedHashes string
		err = rows.Scan(&id, &encodedHashes)
		if err != nil {
			return nil, err
		}
		hashes, err := DecodeFingerprint(encodedHashes)
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
	Debug    bool
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
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	err = db.Ping()
	if err != nil {
		log.Fatalf("Can't ping the database: %v", err)
	}

	idx, err := ConnectWithConfig(context.Background(), cfg.Index)
	if err != nil {
		log.Fatalf("Failed to connect to index: %s", err)
	}
	defer idx.Close(context.Background())

	fp := NewFingerprintStore(db)

	const NoDelay = 0 * time.Millisecond
	const MinDelay = 10 * time.Millisecond
	const MaxDelay = time.Minute

	var delay time.Duration

	for {
		if delay > NoDelay {
			if delay > MaxDelay {
				delay = MaxDelay
			}
			log.Debugf("Sleeping for %v", delay)
			time.Sleep(delay)
		}

		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()

		lastID, err := GetLastFingerprintID(ctx, idx)
		if err != nil {
			log.Errorf("Failed to get the last fingerprint ID in index: %s", err)
			delay = MaxDelay
			continue
		}

		fingerprints, err := fp.GetNextFingerprints(ctx, lastID, UpdateBatchSize)
		if err != nil {
			log.Errorf("Failed to get the next fingerprints to import: %s", err)
			delay = MaxDelay
			continue
		}

		err = MultiInsert(ctx, idx, fingerprints)
		if err != nil {
			log.Errorf("Failed to import the fingerprints: %s", err)
			delay = MaxDelay
			continue
		}

		fingerprintCount := len(fingerprints)
		if fingerprintCount > 0 {
			lastID = fingerprints[fingerprintCount-1].ID
			log.Infof("Added %d fingerprints up to ID %d", fingerprintCount, lastID)
		} else {
			log.Debugf("Added %d fingerprints up to ID %d", fingerprintCount, lastID)
		}

		if fingerprintCount == 0 {
			if delay > NoDelay {
				delay += (delay * 10) / 100
			} else {
				delay = MinDelay
			}
		} else {
			delay = NoDelay
		}
	}
}
