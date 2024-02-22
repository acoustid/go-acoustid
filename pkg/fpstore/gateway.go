package fpstore

import (
	"context"
	"net"
	"net/http"
	"strconv"

	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	"github.com/rs/zerolog/log"
	"github.com/urfave/cli/v2"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	gw "github.com/acoustid/go-acoustid/proto/fpstore"
)

var GatewayListenHostFlag = &cli.StringFlag{
	Name:    "listen-host",
	Usage:   "Listen address",
	Value:   "localhost",
	EnvVars: []string{"FPSTORE_GATEWAY_LISTEN_HOST"},
}

var GatewayListenPortFlag = &cli.IntFlag{
	Name:    "listen-port",
	Usage:   "Listen port",
	Value:   8080,
	EnvVars: []string{"FPSTORE_GATEWAY_LISTEN_PORT"},
}

var GatewayServerHostFlag = &cli.StringFlag{
	Name:    "server-host",
	Usage:   "gRPC server address",
	Value:   "localhost",
	EnvVars: []string{"FPSTORE_GATEWAY_SERVER_HOST"},
}

var GatewayServerPortFlag = &cli.IntFlag{
	Name:    "server-port",
	Usage:   "gRPC server port",
	Value:   4659,
	EnvVars: []string{"FPSTORE_GATEWAY_SERVER_PORT"},
}

var GatewayCommand = &cli.Command{
	Name:  "gateway",
	Usage: "Runs fpstore gRPC gateway",
	Flags: []cli.Flag{
		GatewayListenHostFlag,
		GatewayListenPortFlag,
		GatewayServerHostFlag,
		GatewayServerPortFlag,
	},
	Action: RunGateway,
}

func RunGateway(c *cli.Context) error {
	ctx := context.Background()
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	// Register gRPC server endpoint
	// Note: Make sure the gRPC server is running properly and accessible
	mux := runtime.NewServeMux()
	opts := []grpc.DialOption{
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithDefaultServiceConfig(`{"loadBalancingPolicy":"round_robin"}`),
	}
	endpoint := net.JoinHostPort(GatewayServerHostFlag.Get(c), strconv.Itoa(GatewayServerPortFlag.Get(c)))
	err := gw.RegisterFingerprintStoreHandlerFromEndpoint(ctx, mux, endpoint, opts)
	if err != nil {
		return err
	}

	// Start HTTP server (and proxy calls to gRPC server endpoint)
	listenAddr := net.JoinHostPort(GatewayListenHostFlag.Get(c), strconv.Itoa(GatewayListenPortFlag.Get(c)))
	log.Info().Msgf("Running gRPC gateway on %s", listenAddr)
	return http.ListenAndServe(listenAddr, mux)
}
