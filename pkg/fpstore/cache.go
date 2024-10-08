package fpstore

import (
	"context"
	"fmt"
	"time"

	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	"github.com/pkg/errors"
	"github.com/redis/go-redis/v9"
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
	for i, value := range values {
		if value == nil {
			continue
		}
		fp, err := DecodeFingerprint([]byte(value.(string)))
		if err != nil {
			return nil, errors.WithMessage(err, "failed to unmarshal fingerprint data")
		}
		fpMap[ids[i]] = fp
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
