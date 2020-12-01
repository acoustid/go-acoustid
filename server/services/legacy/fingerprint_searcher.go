package legacy

import (
	"context"
	"fmt"
	"log"
	"sort"
	"time"

	"github.com/acoustid/go-acoustid/chromaprint"
	"github.com/acoustid/go-acoustid/database/fingerprint_db"
	"github.com/acoustid/go-acoustid/proto/index"
	"github.com/acoustid/go-acoustid/server/services"
)

const indexQueryStart = 80
const indexQueryLength = 120
const indexQueryHashBits = 28
const indexQueryHashMask = ((1 << indexQueryHashBits) - 1) << (32 - indexQueryHashBits)

const silenceHash = 627964279

type IndexSearcher interface {
	Search(ctx context.Context, in *index.SearchRequest) (*index.SearchResponse, error)
}

type FingerprintSearcher struct {
	Index          IndexSearcher
	FingerprintDB  *fingerprint_db.FingerprintDB
	MaxCandidates  int
	MinHits        int
	MinHitsPercent int
}

func NewFingerprintSearcher(index IndexSearcher, fingerprintDB *fingerprint_db.FingerprintDB) *FingerprintSearcher {
	searcher := &FingerprintSearcher{Index: index, FingerprintDB: fingerprintDB}
	searcher.MaxCandidates = 10
	searcher.MinHits = 2
	searcher.MinHitsPercent = 50
	return searcher
}

func (searcher *FingerprintSearcher) ExtractIndexQuery(hashes []uint32) []uint32 {
	size := len(hashes)
	silentSize := 0
	for _, hash := range hashes {
		if hash == silenceHash {
			silentSize++
		}
	}
	if silentSize == size {
		return nil
	}

	start := size - silentSize - indexQueryLength
	if start > indexQueryStart {
		start = indexQueryStart
	} else if start < 0 {
		start = 0
	}

	query := make([]uint32, 0)
	queryMap := make(map[uint32]bool)
	end := size
	for i, hash := range hashes[start:] {
		if hash != silenceHash {
			hash &= indexQueryHashMask
			if _, exists := queryMap[hash]; !exists {
				query = append(query, hash)
				queryMap[hash] = true
			}
			if len(query) > indexQueryLength {
				end = start + i
				break
			}
		}
	}
	log.Printf("Extracted index query from hashes between %v and %v", start, end)
	return query
}

func (searcher *FingerprintSearcher) GetCandidates(ctx context.Context, hashes []uint32) ([]int, error) {
	response, err := searcher.Index.Search(ctx, &index.SearchRequest{Hashes: hashes})
	if err != nil {
		return nil, fmt.Errorf("index search failed: %w", err)
	}

	results := response.Results
	if len(results) == 0 {
		return nil, nil
	}

	sort.Slice(results, func(i, j int) bool { return results[i].Hits >= results[j].Hits })

	minHits := int(results[0].Hits) * searcher.MinHitsPercent / 100
	if minHits < searcher.MinHits {
		return nil, nil
	}

	candidates := make([]int, 0)
	for i, result := range results {
		if i > searcher.MaxCandidates || int(result.Hits) < minHits {
			break
		}
		candidates = append(candidates, int(result.Id))
	}
	log.Printf("candidates=%v", candidates)
	return candidates, nil
}

func (s *FingerprintSearcher) Search(ctx context.Context, fingerprint chromaprint.Fingerprint, duration time.Duration) ([]services.FingerprintSearchResult, error) {
	log.Printf("Searching for fingerprint with %v hashess", len(fingerprint.Hashes))
	candidates, err := s.GetCandidates(ctx, s.ExtractIndexQuery(fingerprint.Hashes))
	if err != nil {
		return nil, err
	}

	matches, err := s.FingerprintDB.ScoreSearchMatches(ctx, fingerprint.Hashes, candidates, duration)
	if err != nil {
		return nil, err
	}

	results := make([]services.FingerprintSearchResult, len(matches))
	for i, match := range matches {
		results[i] = services.FingerprintSearchResult{
			TrackID:  match.TrackID,
			TrackGID: match.TrackGID,
			Score:    match.Score,
		}
	}
	return results, nil
}
