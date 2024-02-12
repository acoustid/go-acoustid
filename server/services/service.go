package services

import (
	"context"
	"time"

	common_pb "github.com/acoustid/go-acoustid/proto/common"
)

type FingerprintSearchResult struct {
	TrackID  int
	TrackGID string
	Score    float64
}

type FingerprintSearcher interface {
	Search(ctx context.Context, fingerprint *common_pb.Fingerprint, duration time.Duration) ([]FingerprintSearchResult, error)
}
