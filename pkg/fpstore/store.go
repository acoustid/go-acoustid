package fpstore

import (
	"context"
	"database/sql"
	"errors"

	"github.com/acoustid/go-acoustid/database/fingerprint_db"
	"github.com/acoustid/go-acoustid/pkg/index"
	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	"github.com/rs/zerolog/log"
)

type FingerprintStore interface {
	Insert(ctx context.Context, fp *pb.Fingerprint) (uint64, error)
	Delete(ctx context.Context, id uint64) error
	Get(ctx context.Context, id uint64) (*pb.Fingerprint, error)
}

type PostgresFingerprintStore struct {
	db  *sql.DB
	idx *index.IndexClientPool
}

func NewPostgresFingerprintStore(db *sql.DB) *PostgresFingerprintStore {
	return &PostgresFingerprintStore{db: db}
}

func (s *PostgresFingerprintStore) Insert(ctx context.Context, fp *pb.Fingerprint) (uint64, error) {
	data, err := EncodeFingerprint(fp)
	if err != nil {
		return 0, err
	}
	var id uint64
	err = s.db.QueryRowContext(ctx, "INSERT INTO fingerprint_v2 (data) VALUES ($1) RETURNING id", data).Scan(&id)
	if err != nil {
		return 0, err
	}
	return id, nil
}

var ErrCannotDeleteLegacyFingerprint = errors.New("cannot delete legacy fingerprint")

func (s *PostgresFingerprintStore) Delete(ctx context.Context, id uint64) error {
	existsAsV1, err := s.checkV1(ctx, id)
	if err != nil {
		return err
	}
	if existsAsV1 {
		return ErrCannotDeleteLegacyFingerprint
	}
	_, err = s.db.ExecContext(ctx, "DELETE FROM fingerprint_v2 WHERE id = $1", id)
	return err
}

func (s *PostgresFingerprintStore) checkV1(ctx context.Context, id uint64) (bool, error) {
	var count int
	err := s.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM fingerprint WHERE id = $1", id).Scan(&count)
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

func (s *PostgresFingerprintStore) getV1(ctx context.Context, id uint64) (*pb.Fingerprint, error) {
	var hashes fingerprint_db.Uint32Array
	query := "SELECT fingerprint FROM fingerprint WHERE id = $1"
	err := s.db.QueryRowContext(ctx, query, id).Scan(&hashes)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		log.Warn().Err(err).Msg("failed to get fingerprint from v2 table")
		return nil, err
	}
	return &pb.Fingerprint{Hashes: hashes}, nil
}

func (s *PostgresFingerprintStore) getV2(ctx context.Context, id uint64) (*pb.Fingerprint, error) {
	var data []byte
	query := "SELECT data FROM fingerprint_v2 WHERE id = $1"
	err := s.db.QueryRowContext(ctx, query, id).Scan(&data)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		log.Warn().Err(err).Msg("failed to get fingerprint from v1 table")
		return nil, err
	}
	return DecodeFingerprint(data)
}

func (s *PostgresFingerprintStore) Get(ctx context.Context, id uint64) (*pb.Fingerprint, error) {
	fp, err := s.getV1(ctx, id)
	if err != nil {
		return nil, err
	}
	return fp, nil
}
