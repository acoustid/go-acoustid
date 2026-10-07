package fpstore

import (
	"context"
	"testing"

	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// fakeRedis answers MGet with a canned reply. Embedding redis.Cmdable as a nil
// interface satisfies the rest of it; any other method would panic, and the
// code under test calls none of them.
type fakeRedis struct {
	redis.Cmdable
	values []interface{}
}

func (f fakeRedis) MGet(ctx context.Context, keys ...string) *redis.SliceCmd {
	cmd := redis.NewSliceCmd(ctx, "mget")
	cmd.SetVal(f.values)
	return cmd
}

// redisError stands in for go-redis's proto.RedisError, which lives in that
// module's internal tree and cannot be imported here. The detail that matters
// is reproduced: a named string type, so value.(string) fails on it even
// though the underlying kind is string.
type redisError string

func (e redisError) Error() string { return string(e) }

func encoded(t *testing.T, hashes []uint32) string {
	t.Helper()
	data, err := EncodeFingerprint(&pb.Fingerprint{Hashes: hashes})
	require.NoError(t, err)
	return string(data)
}

func TestGetMulti(t *testing.T) {
	cache := NewRedisFingerprintCache(fakeRedis{values: []interface{}{
		encoded(t, []uint32{7, 8}),
		nil,
		encoded(t, []uint32{9}),
	}})

	fpMap, err := cache.GetMulti(context.Background(), []uint64{1, 2, 3})

	require.NoError(t, err)
	require.Len(t, fpMap, 2)
	assert.Equal(t, []uint32{7, 8}, fpMap[1].Hashes)
	assert.Equal(t, []uint32{9}, fpMap[3].Hashes)
}

func TestGetMultiTreatsPerKeyErrorAsMiss(t *testing.T) {
	// One shard behind the proxy could not answer, so its keys come back as
	// errors in place of values while the MGET itself reports success. This
	// used to panic on an unchecked type assertion, killing the process.
	cache := NewRedisFingerprintCache(fakeRedis{values: []interface{}{
		encoded(t, []uint32{7}),
		redisError("LOADING Redis is loading the dataset in memory"),
		encoded(t, []uint32{9}),
	}})

	fpMap, err := cache.GetMulti(context.Background(), []uint64{1, 2, 3})

	require.NoError(t, err)
	// the unanswered id is simply absent, so the caller reads it from the
	// database along with the genuine misses
	require.Len(t, fpMap, 2)
	assert.NotContains(t, fpMap, uint64(2))
	assert.Equal(t, []uint32{7}, fpMap[1].Hashes)
	assert.Equal(t, []uint32{9}, fpMap[3].Hashes)
}
