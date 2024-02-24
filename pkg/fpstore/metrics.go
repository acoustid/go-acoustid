package fpstore

import (
	"context"
	"net/http"

	grpcprom "github.com/grpc-ecosystem/go-grpc-middleware/providers/prometheus"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func examplarFromContext(ctx context.Context) prometheus.Labels {
	traceId := getTraceId(ctx)
	if traceId != "" {
		return prometheus.Labels{"trace_id": traceId}
	}
	return nil
}

type FingerprintStoreMetrics struct {
	CacheHits   prometheus.Counter
	CacheMisses prometheus.Counter
	GrpcMetrics *grpcprom.ServerMetrics
}

func NewFingerprintStoreMetrics(reg *prometheus.Registry) *FingerprintStoreMetrics {
	metrics := &FingerprintStoreMetrics{
		CacheHits: prometheus.NewCounter(prometheus.CounterOpts{
			Namespace: "acoustid",
			Subsystem: "fpstore",
			Name:      "cache_hits_total",
			Help:      "Number of fingerprint cache hits",
		}),
		CacheMisses: prometheus.NewCounter(prometheus.CounterOpts{
			Namespace: "acoustid",
			Subsystem: "fpstore",
			Name:      "cache_misses_total",
			Help:      "Number of fingerprint cache misses",
		}),
		GrpcMetrics: grpcprom.NewServerMetrics(
			grpcprom.WithServerHandlingTimeHistogram(
				grpcprom.WithHistogramBuckets([]float64{0.01, 0.05, 0.15, 0.5, 1}),
			),
		),
	}
	reg.MustRegister(metrics.CacheHits)
	reg.MustRegister(metrics.CacheMisses)
	reg.MustRegister(metrics.GrpcMetrics)
	return metrics
}

func RunMetricsServer(listenAddr string, reg *prometheus.Registry) error {
	http.Handle("/metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{
		EnableOpenMetrics: true,
	}))
	return http.ListenAndServe(listenAddr, nil)
}
