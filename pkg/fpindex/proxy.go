package fpindex

import (
	"context"
	"net"
	"strconv"
	"time"

	pb "github.com/acoustid/go-acoustid/proto/index"
	"github.com/rs/zerolog/log"
	"github.com/urfave/cli/v2"
	grpc "google.golang.org/grpc"
)

type ProxyConfig struct {
	RequestTimeout time.Duration
	ListenHost     string
	ListenPort     int
	Index          *IndexConfig
	Debug          bool
}

func NewProxyConfig() *ProxyConfig {
	return &ProxyConfig{
		Index: NewIndexConfig(),
	}
}

type Proxy struct {
	pb.UnimplementedIndexServer
	Config *ProxyConfig
	Pool   *IndexClientPool
}

func (p *Proxy) Search(ctx context.Context, in *pb.SearchRequest) (*pb.SearchResponse, error) {
	if p.Config.RequestTimeout > 0 {
		ctxWithTimeout, cancel := context.WithTimeout(ctx, p.Config.RequestTimeout)
		defer cancel()
		ctx = ctxWithTimeout
	}
	return p.Pool.Search(ctx, in)
}

func (p *Proxy) Insert(ctx context.Context, in *pb.InsertRequest) (*pb.InsertResponse, error) {
	if p.Config.RequestTimeout > 0 {
		ctxWithTimeout, cancel := context.WithTimeout(ctx, p.Config.RequestTimeout)
		defer cancel()
		ctx = ctxWithTimeout
	}
	return p.Pool.Insert(ctx, in)
}

func RunProxy(cfg *ProxyConfig) {
	pool := NewIndexClientPool(cfg.Index, 32)
	defer pool.Close(context.Background())

	proxy := &Proxy{Config: cfg, Pool: pool}

	addr := net.JoinHostPort(cfg.ListenHost, strconv.Itoa(cfg.ListenPort))
	lis, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to listen")
		return
	}

	grpcServer := grpc.NewServer()
	pb.RegisterIndexServer(grpcServer, proxy)
	grpcServer.Serve(lis)
}

func RunProxyCommand(c *cli.Context) error {
	cfg := NewProxyConfig()

	cfg.Debug = c.Bool("debug")

	cfg.RequestTimeout = c.Duration("request-timeout")

	cfg.ListenHost = c.String("listen-host")
	cfg.ListenPort = c.Int("listen-port")

	cfg.Index.Host = c.String("index-host")
	cfg.Index.Port = c.Int("index-port")

	RunProxy(cfg)
	return nil
}

var ProxyCommand = &cli.Command{
	Name:  "proxy",
	Usage: "Runs gRPC proxy",
	Flags: []cli.Flag{
		&cli.DurationFlag{
			Name:    "request-timeout",
			Usage:   "request timeout",
			EnvVars: []string{"AINDEX_PROXY_REQUEST_TIMEOUT"},
		},
		&cli.StringFlag{
			Name:    "listen-addr",
			Usage:   "listen address",
			Value:   "localhost",
			EnvVars: []string{"AINDEX_PROXY_LISTEN_ADDR"},
		},
		&cli.IntFlag{
			Name:    "listen-port",
			Usage:   "listen port number",
			Value:   6081,
			EnvVars: []string{"AINDEX_PROXY_LISTEN_PORT"},
		},
		&cli.StringFlag{
			Name:    "index-host",
			Usage:   "index host",
			Value:   "localhost",
			EnvVars: []string{"AINDEX_PROXY_INDEX_ADDR"},
		},
		&cli.IntFlag{
			Name:    "index-port",
			Usage:   "index port number",
			Value:   6080,
			EnvVars: []string{"AINDEX_PROXY_INDEX_PORT"},
		},
	},
	Action: RunProxyCommand,
}
