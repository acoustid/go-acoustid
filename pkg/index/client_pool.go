package index

import (
	"context"
	"time"

	pb "github.com/acoustid/go-acoustid/proto/index"

	pool "github.com/jolestar/go-commons-pool"
	log "github.com/sirupsen/logrus"
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
	err := client.Ping(ctx)
	if err != nil {
		return false
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
	obj, err := p.Pool.BorrowObject(ctx)
	if err != nil {
		log.Errorf("failed to borrow index client from the pool: %v", err)
		return nil, err
	}

	defer func() {
		err := p.Pool.ReturnObject(ctx, obj)
		if err != nil {
			log.Errorf("failed to return index client to the pool: %v", err)
		}
	}()

	idx := obj.(*IndexClient)
	return idx.Search(ctx, in)
}

func (p *IndexClientPool) Insert(ctx context.Context, in *pb.InsertRequest) (*pb.InsertResponse, error) {
	obj, err := p.Pool.BorrowObject(ctx)
	if err != nil {
		log.Errorf("failed to borrow index client from the pool: %v", err)
		return nil, err
	}

	defer func() {
		err := p.Pool.ReturnObject(ctx, obj)
		if err != nil {
			log.Errorf("failed to return index client to the pool: %v", err)
		}
	}()

	idx := obj.(*IndexClient)
	return idx.Insert(ctx, in)
}
