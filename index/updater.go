package index

import (
	"context"
	"database/sql"
	"time"

	"github.com/acoustid/go-acoustid/common"
	"github.com/acoustid/go-acoustid/database/fingerprint_db"
	pb "github.com/acoustid/go-acoustid/proto/index"

	_ "github.com/lib/pq"
	log "github.com/sirupsen/logrus"
)

const UpdateBatchSize = 10000

type UpdaterConfig struct {
	Database *common.DatabaseConfig
	Index    *IndexConfig
	Debug    bool
}

func NewUpdaterConfig() *UpdaterConfig {
	return &UpdaterConfig{
		Database: common.NewDatabaseConfig(),
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
		return
	}
	defer db.Close()

	err = db.Ping()
	if err != nil {
		log.Fatalf("Can't ping the database: %v", err)
		return
	}

	fpDB := fingerprint_db.NewFingerprintDB(db)

	const NoDelay = 0 * time.Millisecond
	const MinDelay = 10 * time.Millisecond
	const MaxDelay = time.Minute

	var delay time.Duration

	var idx *IndexClient

	for {
		if delay > NoDelay {
			if delay > MaxDelay {
				delay = MaxDelay
			}
			log.Debugf("Sleeping for %v", delay)
			time.Sleep(delay)
		}

		if idx == nil {
			idx, err = ConnectWithConfig(context.Background(), cfg.Index)
			if err != nil {
				log.Fatalf("Failed to connect to index: %s", err)
				delay = MaxDelay
				continue
			}
		}

		if !idx.IsOK() {
			log.Infof("Index connection failed, reconnecting...")
			idx.Close(context.Background())
			idx = nil
			delay = MaxDelay
			continue
		}

		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()

		lastID, err := GetLastFingerprintID(ctx, idx)
		if err != nil {
			log.Errorf("Failed to get the last fingerprint ID in index: %s", err)
			delay = MaxDelay
			continue
		}

		fingerprints, err := fpDB.GetNextFingerprints(ctx, lastID, true, UpdateBatchSize)
		if err != nil {
			log.Errorf("Failed to get the next fingerprints to import: %s", err)
			delay = MaxDelay
			continue
		}

		_, err = idx.Insert(ctx, &pb.InsertRequest{Fingerprints: fingerprints})
		if err != nil {
			log.Errorf("Failed to import the fingerprints: %s", err)
			delay = MaxDelay
			continue
		}

		fingerprintCount := len(fingerprints)
		if fingerprintCount > 0 {
			lastID = fingerprints[fingerprintCount-1].Id
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

	if idx != nil {
		idx.Close(context.Background())
	}
}
