package index

import (
	"context"
	"time"

	"github.com/jolestar/go-commons-pool"
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

func NewIndexClientPool(config *IndexConfig, limit int) *pool.ObjectPool {
	ctx := context.Background()
	factory := &IndexClientFactory{Config: config}
	poolConfig := pool.NewDefaultPoolConfig()
	poolConfig.MaxTotal = limit
	poolConfig.MaxIdle = limit
	poolConfig.TestWhileIdle = true
	poolConfig.TimeBetweenEvictionRuns = 10*time.Second
	return pool.NewObjectPool(ctx, factory, poolConfig)
}
