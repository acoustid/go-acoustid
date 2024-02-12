package fpstore

import (
	"testing"

	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	index_pb "github.com/acoustid/go-acoustid/proto/index"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestFilterIndexSearchResults_1(t *testing.T) {
	results := []*index_pb.Result{
		{Hits: 1, Id: 1},
		{Hits: 2, Id: 2},
		{Hits: 3, Id: 3},
		{Hits: 4, Id: 4},
	}

	filtered := filterIndexSearchResults(results, 2)
	require.Equal(t, 2, len(filtered))
	assert.Equal(t, uint32(4), filtered[0].Id)
	assert.Equal(t, uint32(3), filtered[1].Id)
}

func TestFilterIndexSearchResults_2(t *testing.T) {
	results := []*index_pb.Result{
		{Hits: 1, Id: 1},
		{Hits: 50, Id: 2},
		{Hits: 3, Id: 3},
		{Hits: 100, Id: 4},
	}

	filtered := filterIndexSearchResults(results, 2)
	require.Equal(t, 2, len(filtered))
	assert.Equal(t, uint32(4), filtered[0].Id)
	assert.Equal(t, uint32(2), filtered[1].Id)
}

func TestFilterIndexSearchResults_3(t *testing.T) {
	results := []*index_pb.Result{
		{Hits: 1, Id: 1},
		{Hits: 2, Id: 2},
		{Hits: 3, Id: 3},
		{Hits: 100, Id: 4},
	}

	filtered := filterIndexSearchResults(results, 2)
	require.Equal(t, 1, len(filtered))
	assert.Equal(t, uint32(4), filtered[0].Id)
}

func signedToUnsignedHashes(signedHashes []int32) []uint32 {
	hashes := make([]uint32, len(signedHashes))
	for i, hash := range signedHashes {
		hashes[i] = uint32(hash)
	}
	return hashes
}

func TestExtractLegacyQuery(t *testing.T) {
	fp := &pb.Fingerprint{Hashes: signedToUnsignedHashes([]int32{506444819, 1064287265, 1055763488, 2142086176, 2137886720, 2100269056, -63994816, -64039456})}
	query := ExtractLegacyQuery(fp)
	assert.Equal(t, signedToUnsignedHashes([]int32{506444816, 1064287264, 1055763488, 2142086176, 2137886720, 2100269056, -63994816, -64039456}), query)
}
