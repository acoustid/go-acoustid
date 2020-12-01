package services

import (
	"context"
	"time"

	"github.com/acoustid/go-acoustid/chromaprint"
)

type FingerprintSearchResult struct {
	TrackID  int
	TrackGID string
	Score    float64
}

type FingerprintSearcher interface {
	Search(ctx context.Context, fingerprint chromaprint.Fingerprint, duration time.Duration) ([]FingerprintSearchResult, error)
}
