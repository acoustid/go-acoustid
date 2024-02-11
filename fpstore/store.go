package fpstore

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"fmt"
	"strconv"
	"strings"

	log "github.com/sirupsen/logrus"

	pb "github.com/acoustid/go-acoustid/proto/fpstore"
)

type FingerprintStore interface {
	Insert(ctx context.Context, fp *pb.Fingerprint) (uint64, error)
	Delete(ctx context.Context, id uint64) error
	Get(ctx context.Context, id uint64) (*pb.Fingerprint, error)
}

type Uint32Array []uint32

func (a Uint32Array) Value() (driver.Value, error) {
	if a == nil {
		return nil, nil
	}
	var builder strings.Builder
	builder.WriteRune('{')
	for i, item := range a {
		if i > 0 {
			builder.WriteRune(',')
		}
		builder.WriteString(strconv.FormatInt(int64(int32(item)), 10))
	}
	builder.WriteRune('}')
	return builder.String(), nil
}

func (a *Uint32Array) Scan(src interface{}) error {
	switch src := src.(type) {
	case []byte:
		return a.scanString(string(src))
	case string:
		return a.scanString(src)
	case nil:
		*a = nil
		return nil
	}
	return fmt.Errorf("cannot convert %T to Uint32Array", src)
}

func (a *Uint32Array) scanString(src string) error {
	if strings.HasPrefix(src, "{") && strings.HasSuffix(src, "}") {
		src = strings.Trim(src, "{}")
	}
	items := strings.Split(src, ",")
	result := make([]uint32, len(items))
	for i, item := range items {
		value, err := strconv.ParseInt(item, 10, 32)
		if err != nil {
			return err
		}
		result[i] = uint32(int32(value))
	}
	*a = result
	return nil
}

type SqlFingerprintStore struct {
	db *sql.DB
}

func NewSqlFingerprintStore(db *sql.DB) *SqlFingerprintStore {
	return &SqlFingerprintStore{db: db}
}

func (s *SqlFingerprintStore) Insert(ctx context.Context, fp *pb.Fingerprint) (uint64, error) {
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

func (s *SqlFingerprintStore) Delete(ctx context.Context, id uint64) error {
	_, err := s.db.ExecContext(ctx, "DELETE FROM fingerprint_v2 WHERE id = $1", id)
	return err
}

func (s *SqlFingerprintStore) getV1(ctx context.Context, id uint64) (*pb.Fingerprint, error) {
	var hashes Uint32Array
	query := "SELECT fingerprint FROM fingerprint WHERE id = $1"
	err := s.db.QueryRowContext(ctx, query, id).Scan(&hashes)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrFingerprintNotFound
		}
		return nil, err
	}
	return &pb.Fingerprint{Hashes: hashes}, nil
}

func (s *SqlFingerprintStore) getV2(ctx context.Context, id uint64) (*pb.Fingerprint, error) {
	var data []byte
	query := "SELECT data FROM fingerprint_v2 WHERE id = $1"
	err := s.db.QueryRowContext(ctx, query, id).Scan(&data)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrFingerprintNotFound
		}
		return nil, err
	}
	return DecodeFingerprint(data)
}

func (s *SqlFingerprintStore) Get(ctx context.Context, id uint64) (*pb.Fingerprint, error) {
	fp, err := s.getV2(ctx, id)
	if err != nil {
		if err != ErrFingerprintNotFound {
			log.Warnf("failed to get fingerprint from v2 table: %v", err)
			return nil, err
		}
		fp, err = s.getV1(ctx, id)
		if err != nil {
			if err != ErrFingerprintNotFound {
				log.Warnf("failed to get fingerprint from v1 table: %v", err)
				return nil, err
			}
			return nil, ErrFingerprintNotFound
		}
	}
	return fp, nil
}
