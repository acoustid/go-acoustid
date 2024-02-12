package fpstore

import (
	"context"
	"sort"

	"github.com/acoustid/go-acoustid/pkg/fpindex"
	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	index_pb "github.com/acoustid/go-acoustid/proto/index"
)

type FingerprintIndex interface {
	Search(ctx context.Context, fp *pb.Fingerprint, limit int) ([]uint64, error)
}

type FingerprintIndexClient struct {
	clientPool *fpindex.IndexClientPool
}

func NewFingerprintIndexClient(clientPool *fpindex.IndexClientPool) *FingerprintIndexClient {
	return &FingerprintIndexClient{clientPool: clientPool}
}

// Legacy compatibility with https://github.com/acoustid/pg_acoustid/blob/main/acoustid_compare.c#L348
func ExtractLegacyQuery(fp *pb.Fingerprint) []uint32 {
	const QuerySize = 120
	const QueryStart = 80

	const NumQueryBits = 28
	const QueryBitMask = ((1 << NumQueryBits) - 1) << (32 - NumQueryBits)

	const SilenceHash = 627964279

	cleanSize := 0
	for _, hash := range fp.Hashes {
		if hash != SilenceHash {
			cleanSize++
		}
	}

	if cleanSize <= 0 {
		return nil
	}

	query := make([]uint32, QuerySize)
	queryHashes := make(map[uint32]struct{})
	querySize := 0

	for i := max(0, min(cleanSize-QuerySize, QueryStart)); i < len(fp.Hashes) && querySize < QuerySize; i++ {
		hash := fp.Hashes[i]
		if hash == SilenceHash {
			continue
		}
		hash &= QueryBitMask
		if _, ok := queryHashes[hash]; ok {
			continue
		}
		queryHashes[hash] = struct{}{}
		query[querySize] = hash
		querySize++
	}

	query = query[:querySize]
	return query
}

func filterIndexSearchResults(results []*index_pb.Result, limit int) []*index_pb.Result {
	sort.Slice(results, func(i, j int) bool {
		return results[i].Hits > results[j].Hits || (results[i].Hits == results[j].Hits && results[i].Id < results[j].Id)
	})
	if limit == 0 || len(results) > limit {
		threshold := (results[0].Hits*10 + 50) / 100
		thresholdIndex := sort.Search(len(results), func(i int) bool {
			return results[i].Hits < threshold
		})
		if limit == 0 || limit > thresholdIndex {
			limit = thresholdIndex
		}
	}
	if limit > 0 && len(results) > limit {
		results = results[:limit]
	}
	return results
}

func (c *FingerprintIndexClient) Search(ctx context.Context, fp *pb.Fingerprint, limit int) ([]uint64, error) {
	req := &index_pb.SearchRequest{Hashes: ExtractLegacyQuery(fp)}
	resp, err := c.clientPool.Search(ctx, req)
	if err != nil {
		return nil, err
	}

	results := filterIndexSearchResults(resp.Results, limit)

	ids := make([]uint64, len(results))
	for i, result := range results {
		ids[i] = uint64(result.Id)
	}
	return ids, nil
}
