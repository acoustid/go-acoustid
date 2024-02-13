package fpstore

import (
	"context"
	"fmt"
	"time"

	"net"

	"github.com/rs/zerolog/log"

	"github.com/acoustid/go-acoustid/pkg/chromaprint"
	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"
)

type FingerprintStoreService struct {
	pb.UnimplementedFingerprintStoreServer
	store FingerprintStore
	index FingerprintIndex
	cache FingerprintCache
}

func FingerprintStoreServiceInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
	log.Info().Str("method", info.FullMethod).Msg("Handling request")
	return handler(ctx, req)
}

func RunFingerprintStoreServer(listenAddr string, service pb.FingerprintStoreServer) error {
	server := grpc.NewServer(grpc.UnaryInterceptor(FingerprintStoreServiceInterceptor))
	pb.RegisterFingerprintStoreServer(server, service)
	reflection.Register(server)
	lis, err := net.Listen("tcp", listenAddr)
	if err != nil {
		return err
	}
	return server.Serve(lis)
}

func NewFingerprintStoreService(store FingerprintStore, index FingerprintIndex, cache FingerprintCache) *FingerprintStoreService {
	return &FingerprintStoreService{store: store, index: index, cache: cache}
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

func (s *FingerprintStoreService) compareFingerprints(ctx context.Context, query *pb.Fingerprint, ids []uint64) ([]*pb.MatchingFingerprint, error) {
	var results []*pb.MatchingFingerprint
	for _, id := range ids {
		if ctx.Err() == context.Canceled {
			return nil, status.Error(codes.Canceled, "request canceled")
		}
		if id == 0 {
			return nil, status.Error(codes.InvalidArgument, "id is required")
		}
		fp, err := s.getFingerprint(ctx, id)
		if err != nil {
			return nil, status.Error(codes.Internal, fmt.Sprintf("failed to get fingerprint %d", id))
		}
		if fp == nil {
			continue
		}
		score, err := chromaprint.CompareFingerprints(query, fp)
		results = append(results, &pb.MatchingFingerprint{Id: id, Similarity: float32(score)})
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
	results, err := s.compareFingerprints(ctx, req.Fingerprint, req.Ids)
	if err != nil {
		return nil, err
	}
	return &pb.CompareFingerprintResponse{Results: results}, nil
}

const DefaultSearchLimit = 10
const FastModeFactor = 1
const SlowModeFactor = 4

func (s *FingerprintStoreService) Search(ctx context.Context, req *pb.SearchFingerprintRequest) (*pb.SearchFingerprintResponse, error) {
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
	if req.FastMode {
		maxCandidateIds = maxResults * FastModeFactor
	} else {
		maxCandidateIds = maxResults * SlowModeFactor
	}

	candidateIds, err := s.index.Search(ctx, req.Fingerprint, maxCandidateIds)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to search index")
	}

	log.Debug().Int("candidates", len(candidateIds)).Msg("received candidates")

	startTime := time.Now()

	results, err := s.compareFingerprints(ctx, req.Fingerprint, candidateIds)
	if err != nil {
		return nil, err
	}
	if len(results) > maxResults {
		results = results[:maxResults]
	}

	log.Debug().Dur("duration", time.Since(startTime)).Int("results", len(results)).Msg("search finished")

	return &pb.SearchFingerprintResponse{Results: results}, nil
}
