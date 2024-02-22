package fpstore

import (
	"context"
	"fmt"

	"net"

	"github.com/acoustid/go-acoustid/pkg/chromaprint"
	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	grpclogging "github.com/grpc-ecosystem/go-grpc-middleware/v2/interceptors/logging"
	"github.com/rs/zerolog/log"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"
)

type FingerprintStoreService struct {
	pb.UnimplementedFingerprintStoreServer
	store   FingerprintStore
	index   FingerprintIndex
	cache   FingerprintCache
	metrics *FingerprintStoreMetrics
}

func interceptorLogger() grpclogging.Logger {
	return grpclogging.LoggerFunc(func(_ context.Context, lvl grpclogging.Level, msg string, fields ...any) {
		switch lvl {
		case grpclogging.LevelDebug:
			log.Debug().Fields(fields).Msg(msg)
		case grpclogging.LevelInfo:
			log.Info().Fields(fields).Msg(msg)
		case grpclogging.LevelWarn:
			log.Warn().Fields(fields).Msg(msg)
		case grpclogging.LevelError:
			log.Error().Fields(fields).Msg(msg)
		default:
			panic(fmt.Sprintf("unknown level %v", lvl))
		}
	})
}

func RunFingerprintStoreServer(listenAddr string, service *FingerprintStoreService) error {
	server := grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			service.metrics.GrpcMetrics.UnaryServerInterceptor(),
			grpclogging.UnaryServerInterceptor(interceptorLogger()),
		),
		grpc.ChainStreamInterceptor(
			service.metrics.GrpcMetrics.StreamServerInterceptor(),
			grpclogging.StreamServerInterceptor(interceptorLogger()),
		),
	)
	pb.RegisterFingerprintStoreServer(server, service)
	grpc_health_v1.RegisterHealthServer(server, health.NewServer())
	reflection.Register(server)
	lis, err := net.Listen("tcp", listenAddr)
	if err != nil {
		return err
	}
	return server.Serve(lis)
}

func NewFingerprintStoreService(store FingerprintStore, index FingerprintIndex, cache FingerprintCache, metrics *FingerprintStoreMetrics) *FingerprintStoreService {
	return &FingerprintStoreService{store: store, index: index, cache: cache, metrics: metrics}
}

// Implement Insert method
func (s *FingerprintStoreService) Insert(ctx context.Context, req *pb.InsertFingerprintRequest) (*pb.InsertFingerprintResponse, error) {
	fp := req.Fingerprint
	if fp == nil {
		return nil, status.Error(codes.InvalidArgument, "fingerprint is required")
	}
	if len(fp.Hashes) == 0 {
		return nil, status.Error(codes.InvalidArgument, "fingerprint can't be empty")
	}
	id, err := s.store.Insert(ctx, fp)
	if err != nil {
		log.Printf("failed to insert fingerprint: %v", err)
		return nil, status.Error(codes.Internal, "failed to insert fingerprint")
	}
	s.cache.Set(ctx, id, fp)
	return &pb.InsertFingerprintResponse{Id: id}, nil
}

func (s *FingerprintStoreService) getFingerprint(ctx context.Context, id uint64) (*pb.Fingerprint, error) {
	fp, err := s.cache.Get(ctx, id)
	if err != nil {
		log.Printf("failed to get fingerprint from cache: %v", err)
	}
	if fp == nil {
		fp, err = s.store.Get(ctx, id)
		if err != nil {
			log.Printf("failed to get fingerprint from store: %v", err)
			return nil, err
		}
		if fp == nil {
			return nil, nil
		}
		s.cache.Set(ctx, id, fp)
	}
	return fp, nil
}

func (s *FingerprintStoreService) getFingerprints(ctx context.Context, ids []uint64) (map[uint64]*pb.Fingerprint, error) {
	cachedFingerprints, err := s.cache.GetMulti(ctx, ids)
	if err != nil {
		log.Err(err).Msg("failed to get fingerprints from cache")
		return nil, status.Error(codes.Internal, "failed to get fingerprints from cache")
	}

	missingIds := make([]uint64, 0, len(ids))
	for _, id := range ids {
		if _, ok := cachedFingerprints[id]; !ok {
			missingIds = append(missingIds, id)
		}
	}

	s.metrics.CacheHits.Add(float64(len(ids) - len(missingIds)))
	s.metrics.CacheMisses.Add(float64(len(missingIds)))

	if len(missingIds) > 0 {
		fps, err := s.store.GetMulti(ctx, missingIds)
		if err != nil {
			log.Err(err).Msg("failed to get fingerprints from database")
			return nil, status.Error(codes.Internal, "failed to get fingerprints from database")
		}
		for id, fp := range fps {
			cachedFingerprints[id] = fp
			s.cache.Set(ctx, id, fp)
		}
	}

	return cachedFingerprints, nil
}

func (s *FingerprintStoreService) compareFingerprints(ctx context.Context, query *pb.Fingerprint, ids []uint64, minScore float32) ([]*pb.MatchingFingerprint, error) {
	fingerprints, err := s.getFingerprints(ctx, ids)
	if err != nil {
		return nil, err
	}

	var results []*pb.MatchingFingerprint
	for id, fp := range fingerprints {
		if ctx.Err() == context.Canceled {
			return nil, status.Error(codes.Canceled, "request canceled")
		}
		if fp == nil {
			continue
		}
		score, err := chromaprint.CompareFingerprints(query, fp)
		if err != nil {
			log.Err(err).Msg("failed to compare fingerprints")
			return nil, status.Error(codes.Internal, "failed to compare fingerprints")
		}
		if score >= minScore {
			results = append(results, &pb.MatchingFingerprint{Id: id, Score: score})
		}
	}
	return results, nil
}

func (s *FingerprintStoreService) Get(ctx context.Context, req *pb.GetFingerprintRequest) (*pb.GetFingerprintResponse, error) {
	id := req.Id
	if id == 0 {
		return nil, status.Error(codes.InvalidArgument, "id is required")
	}
	fp, err := s.getFingerprint(ctx, id)
	if err != nil {
		return nil, status.Error(codes.Internal, fmt.Sprintf("failed to get fingerprint %d", id))
	}
	if fp == nil {
		return nil, status.Error(codes.NotFound, fmt.Sprintf("fingerprint %d not found", id))
	}
	return &pb.GetFingerprintResponse{Fingerprint: fp}, nil
}

func (s *FingerprintStoreService) Compare(ctx context.Context, req *pb.CompareFingerprintRequest) (*pb.CompareFingerprintResponse, error) {
	if len(req.Fingerprint.Hashes) == 0 {
		return nil, status.Error(codes.InvalidArgument, "fingerprint can't be empty")
	}
	if len(req.Ids) == 0 {
		return nil, status.Error(codes.InvalidArgument, "ids can't be empty")
	}
	results, err := s.compareFingerprints(ctx, req.Fingerprint, req.Ids, req.MinScore)
	if err != nil {
		return nil, err
	}
	return &pb.CompareFingerprintResponse{Results: results}, nil
}

const DefaultSearchLimit = 10
const FastModeFactor = 1
const SlowModeFactor = 4

func (s *FingerprintStoreService) Search(ctx context.Context, req *pb.SearchFingerprintRequest) (*pb.SearchFingerprintResponse, error) {
	logger := log.Logger.With().Str("component", "fpstore").Str("method", "Search").Logger()
	ctx = logger.WithContext(ctx)

	if len(req.Fingerprint.Hashes) == 0 {
		return nil, status.Error(codes.InvalidArgument, "fingerprint can't be empty")
	}

	var maxResults int
	if req.Limit > 0 {
		maxResults = int(req.Limit)
	} else {
		maxResults = DefaultSearchLimit
	}

	var maxCandidateIds int
	req.FastMode = true
	if req.FastMode {
		maxCandidateIds = maxResults * FastModeFactor
	} else {
		maxCandidateIds = maxResults * SlowModeFactor
	}

	candidateIds, err := s.index.Search(ctx, req.Fingerprint, maxCandidateIds)
	if err != nil {
		logger.Err(err).Msg("failed to search index")
		return nil, status.Error(codes.Internal, "failed to search index")
	}

	logger.Debug().Int("candidates", len(candidateIds)).Msg("received candidates")

	results, err := s.compareFingerprints(ctx, req.Fingerprint, candidateIds, req.MinScore)
	if err != nil {
		return nil, err
	}
	if len(results) > maxResults {
		results = results[:maxResults]
	}

	return &pb.SearchFingerprintResponse{Results: results}, nil
}
