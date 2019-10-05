package fingerprint_db

import (
	"context"
	"database/sql"
	"fmt"
	pb "github.com/acoustid/go-acoustid/proto/index"
)

// GetLastFingerprintID returns the maximum fingerprint ID found in the database.
// Since the fingerprint database is append-only, you can use this to
// synchronize an externally replicated database.
func (s *FingerprintDB) GetLastFingerprintID(ctx context.Context) (int, error) {
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

// GetNextFingerprints returns an array of fingerprints with ID higher than lastID.
func (s *FingerprintDB) GetNextFingerprints(ctx context.Context, lastID uint32, extractQuery bool, limit int) ([]*pb.Fingerprint, error) {
	queryTpl := "SELECT id, %s AS fingerprint FROM fingerprint WHERE id > $1 ORDER BY id LIMIT $2"
	var query string
	if extractQuery {
		query = fmt.Sprintf(queryTpl, "acoustid_extract_query(fingerprint)")
	} else {
		query = fmt.Sprintf(queryTpl, "fingerprint")
	}
	rows, err := s.db.QueryContext(ctx, query, lastID, limit)
	if err != nil {
		return nil, err
	}
	var fingerprints []*pb.Fingerprint
	for rows.Next() {
		var id uint32
		hashes := Uint32Array{}
		err = rows.Scan(&id, &hashes)
		if err != nil {
			return nil, err
		}
		fingerprints = append(fingerprints, &pb.Fingerprint{Id: id, Hashes: hashes})
	}
	err = rows.Close()
	if err != nil {
		return nil, err
	}
	return fingerprints, nil
}

