package index

import (
	"context"
	"database/sql"
	"log"
	"time"

	"github.com/lib/pq"
)

type FingerprintStore struct {
	db *sql.DB
}

func NewFingerprintStore(db *sql.DB) *FingerprintStore {
	return &FingerprintStore{
		db: db,
	}
}

func (s *FingerprintStore) GetMaxID() (int, error) {
	row := s.db.QueryRow("SELECT max(id) FROM fingerprint")
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

func (s *FingerprintStore) GetNextFingerprints(lastID uint32, limit int) ([]FingerprintInfo, error) {
	rows, err := s.db.Query("SELECT id, acoustid_extract_query(fingerprint) FROM fingerprint WHERE id > $1 ORDER BY id LIMIT $2", lastID, limit)
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
	return fingerprints, nil
}

type UpdaterConfig struct {
	Database *DatabaseConfig
	Index    *IndexConfig
}

func NewUpdaterConfig() *UpdaterConfig {
	return &UpdaterConfig{
		Database: NewDatabaseConfig(),
		Index:    NewIndexConfig(),
	}
}

func main() {
	cfg := NewUpdaterConfig()

	db, err := sql.Open("postgres", cfg.Database.URL().String())
	if err != nil {
		log.Fatalf("Failed to connect to database: %s", err)
	}
	defer db.Close()

	idx, err := ConnectWithConfig(cfg.Index)
	if err != nil {
		log.Fatalf("Failed to connect to index: %s", err)
	}
	defer idx.Close()

	fp := NewFingerprintStore(db)

	for {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()

		lastID, err := idx.GetLastFingerprintID(ctx)
		if err != nil {
			log.Fatalf("Failed to get the last fingerprint ID in index: %s", err)
		}
		log.Printf("Last fingerprint in index = %d", lastID)

		fingerprints, err := fp.GetNextFingerprints(lastID+1, 1000)
		idx.Insert(ctx, fingerprints)

		time.Sleep(100 * time.Millisecond)
	}
}
