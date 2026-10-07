package fpstore

import (
	"context"
	"fmt"
	"time"

	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	"github.com/pkg/errors"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog"
)

type FingerprintCache interface {
	Get(ctx context.Context, id uint64) (*pb.Fingerprint, error)
	GetMulti(ctx context.Context, ids []uint64) (map[uint64]*pb.Fingerprint, error)
	Set(ctx context.Context, id uint64, fp *pb.Fingerprint) error
}

type RedisFingerprintCache struct {
	cache redis.Cmdable
	ttl   time.Duration
}

func NewRedisFingerprintCache(cache redis.Cmdable) *RedisFingerprintCache {
	return &RedisFingerprintCache{
		cache: cache,
		ttl:   7 * 24 * time.Hour,
	}
}

func (c *RedisFingerprintCache) cacheKey(id uint64) string {
	return fmt.Sprintf("f:%x", id)
}

func (c *RedisFingerprintCache) GetMulti(ctx context.Context, ids []uint64) (map[uint64]*pb.Fingerprint, error) {
	if len(ids) == 0 {
		return nil, nil
	}

	keys := make([]string, len(ids))
	for i, id := range ids {
		keys[i] = c.cacheKey(id)
	}
	values, err := c.cache.MGet(ctx, keys...).Result()
	if err != nil {
		return nil, errors.WithMessagef(err, "failed to get %v fingerprints from cache", len(keys))
	}
	fpMap := make(map[uint64]*pb.Fingerprint, len(ids))
	var failed int
	var reason string
	for i, value := range values {
		if value == nil {
			continue
		}
		// A key whose shard could not be reached arrives as a per-key error
		// reply, which go-redis stores in the slice as the value while
		// reporting no error for the command itself. Asserting it to a string
		// without checking panicked, and a panic in a gRPC handler is the
		// process rather than the request. A cache that cannot answer is a
		// cache miss.
		data, ok := value.(string)
		if !ok {
			failed++
			if reason == "" {
				reason = fmt.Sprintf("%v (%T)", value, value)
			}
			continue
		}
		fp, err := DecodeFingerprint([]byte(data))
		if err != nil {
			return nil, errors.WithMessage(err, "failed to unmarshal fingerprint data")
		}
		fpMap[ids[i]] = fp
	}
	if failed > 0 {
		// Once per call, not per key, so an outage does not trade a crash for
		// a log flood. These ids are counted as ordinary cache misses
		// upstream, so this line is the only sign the cache itself is unwell.
		zerolog.Ctx(ctx).Warn().
			Int("failed", failed).
			Int("requested", len(keys)).
			Str("reason", reason).
			Msg("cache could not answer some keys, treating them as misses")
	}
	return fpMap, nil
}

func (c *RedisFingerprintCache) Get(ctx context.Context, id uint64) (*pb.Fingerprint, error) {
	key := c.cacheKey(id)
	value, err := c.cache.Get(ctx, key).Bytes()
	if err != nil {
		if err == redis.Nil {
			return nil, nil
		}
		return nil, errors.WithMessage(err, "failed to get fingerprint from cache")
	}
	fp, err := DecodeFingerprint(value)
	if err != nil {
		return nil, errors.WithMessage(err, "failed to unmarshal fingerprint data")
	}
	return fp, nil
}

func (c *RedisFingerprintCache) Set(ctx context.Context, id uint64, fp *pb.Fingerprint) error {
	key := c.cacheKey(id)
	value, err := EncodeFingerprint(fp)
	if err != nil {
		return errors.WithMessage(err, "failed to marshal fingerprint data")
	}
	err = c.cache.Set(ctx, key, value, c.ttl).Err()
	if err != nil {
		return errors.WithMessage(err, "failed to set fingerprint in cache")
	}
	return nil
}

func (c *RedisFingerprintCache) Delete(ctx context.Context, id uint64) error {
	key := c.cacheKey(id)
	err := c.cache.Del(ctx, key).Err()
	if err != nil {
		return errors.WithMessage(err, "failed to delete fingerprint from cache")
	}
	return nil
}
