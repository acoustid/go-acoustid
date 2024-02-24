package fpindex

import (
	"context"
	"time"

	pb "github.com/acoustid/go-acoustid/proto/index"

	pool "github.com/jolestar/go-commons-pool"
	"github.com/rs/zerolog"
)

type IndexClientFactory struct {
	Config *IndexConfig
}

func (f IndexClientFactory) MakeObject(ctx context.Context) (*pool.PooledObject, error) {
	client, err := ConnectWithConfig(ctx, f.Config)
	if err != nil {
		return nil, err
	}
	return pool.NewPooledObject(client), nil
}

func (f IndexClientFactory) DestroyObject(ctx context.Context, obj *pool.PooledObject) error {
	client := obj.Object.(*IndexClient)
	return client.Close(ctx)
}

func (f IndexClientFactory) ValidateObject(ctx context.Context, obj *pool.PooledObject) bool {
	client := obj.Object.(*IndexClient)
	if !client.IsOK() {
		return false
	}
	now := time.Now()
	if now.Sub(obj.CreateTime) > f.Config.MaxKeepAlive {
		return false
	}
	if now.Sub(obj.LastBorrowTime) > f.Config.PingInterval {
		err := client.Ping(ctx)
		if err != nil {
			return false
		}
	}
	return true
}

func (f IndexClientFactory) ActivateObject(ctx context.Context, obj *pool.PooledObject) error {
	client := obj.Object.(*IndexClient)
	if !client.IsOK() {
		return ErrClientNotOK
	}
	return nil
}

func (f IndexClientFactory) PassivateObject(ctx context.Context, obj *pool.PooledObject) error {
	client := obj.Object.(*IndexClient)
	if !client.IsOK() {
		return ErrClientNotOK
	}
	return nil
}

func NewIndexClientPool(config *IndexConfig, limit int) *IndexClientPool {
	ctx := context.Background()
	factory := &IndexClientFactory{Config: config}
	poolConfig := pool.NewDefaultPoolConfig()
	poolConfig.MaxTotal = limit
	poolConfig.MaxIdle = limit
	poolConfig.TestWhileIdle = true
	poolConfig.TestOnBorrow = true
	poolConfig.TimeBetweenEvictionRuns = 10 * time.Second
	pool := pool.NewObjectPool(ctx, factory, poolConfig)
	return &IndexClientPool{Pool: pool}
}

type IndexClientPool struct {
	Pool *pool.ObjectPool
}

func (p *IndexClientPool) Close(ctx context.Context) {
	p.Pool.Close(ctx)
}

func (p *IndexClientPool) Search(ctx context.Context, in *pb.SearchRequest) (*pb.SearchResponse, error) {
	logger := zerolog.Ctx(ctx)

	obj, err := p.Pool.BorrowObject(ctx)
	if err != nil {
		logger.Error().Err(err).Msg("failed to borrow index client from the pool")
		return nil, err
	}

	defer func() {
		err := p.Pool.ReturnObject(ctx, obj)
		if err != nil {
			logger.Error().Err(err).Msg("failed to return index client from the pool")
		}
	}()

	idx := obj.(*IndexClient)
	return idx.Search(ctx, in)
}

func (p *IndexClientPool) Insert(ctx context.Context, in *pb.InsertRequest) (*pb.InsertResponse, error) {
	logger := zerolog.Ctx(ctx)

	obj, err := p.Pool.BorrowObject(ctx)
	if err != nil {
		logger.Error().Err(err).Msg("failed to borrow index client from the pool")
		return nil, err
	}

	defer func() {
		err := p.Pool.ReturnObject(ctx, obj)
		if err != nil {
			logger.Error().Err(err).Msg("failed to return index client from the pool")
		}
	}()

	idx := obj.(*IndexClient)
	return idx.Insert(ctx, in)
}
