package fpindex

import (
	"context"
	"strconv"
)

type Index interface {
	IsOK() bool
	Close(ctx context.Context) error
	GetAttribute(ctx context.Context, name string) (string, error)
	SetAttribute(ctx context.Context, name string, value string) error
	BeginTx(ctx context.Context) (Tx, error)
}

type Tx interface {
	Insert(ctx context.Context, id uint32, hashes []uint32) error
	Commit(ctx context.Context) error
	Rollback(ctx context.Context) error
}

func GetLastFingerprintID(ctx context.Context, idx Index) (uint32, error) {
	strValue, err := idx.GetAttribute(ctx, "max_document_id")
	if err != nil {
		return 0, err
	}
	if strValue == "" {
		return 0, nil
	}
	value, err := strconv.ParseUint(strValue, 10, 32)
	if err != nil {
		return 0, err
	}
	return uint32(value), nil
}
