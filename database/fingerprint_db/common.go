package fingerprint_db

import (
	"database/sql"
)

type FingerprintDB struct {
	db *sql.DB
}

func NewFingerprintDB(db *sql.DB) *FingerprintDB {
	return &FingerprintDB{db: db}
}

func (s *FingerprintDB) Close() error {
	return nil
}
