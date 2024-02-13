package fpstore

import (
	"context"
	"fmt"
	"time"

	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	"github.com/go-redis/redis/v8"
	"github.com/pkg/errors"
	"github.com/rs/zerolog/log"
)

type FingerprintCache interface {
	Get(ctx context.Context, id uint64) (*pb.Fingerprint, error)
	Set(ctx context.Context, id uint64, fp *pb.Fingerprint) error
}

type RedisFingerprintCache struct {
	cache *redis.Client
	ttl   time.Duration
}

func NewRedisFingerprintCache(options *redis.Options) *RedisFingerprintCache {
	return &RedisFingerprintCache{
		cache: redis.NewClient(options),
		ttl:   24 * time.Hour,
	}
}

func (c *RedisFingerprintCache) cacheKey(id uint64) string {
	return fmt.Sprintf("f:%x", id)
}

func (c *RedisFingerprintCache) Get(ctx context.Context, id uint64) (*pb.Fingerprint, error) {
	key := c.cacheKey(id)
	t0 := time.Now()
	value, err := c.cache.Get(ctx, key).Bytes()
	if err != nil {
		if err == redis.Nil {
			return nil, nil
		}
		return nil, errors.WithMessage(err, "failed to get fingerprint from cache")
	}
	log.Debug().Dur("get_duration", time.Since(t0)).Uint64("id", id).Msg("Got fingerprint from cache")
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
