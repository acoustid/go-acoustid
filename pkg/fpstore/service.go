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

func (s *FingerprintStoreService) getFingerprints(ctx context.Context, ids []uint64) (map[uint64]*pb.Fingerprint, error) {
	cachedFingerprints, err := s.cache.GetMulti(ctx, ids)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to get fingerprints from cache")
	}

	missingIds := make([]uint64, 0, len(ids))
	for _, id := range ids {
		if _, ok := cachedFingerprints[id]; !ok {
			missingIds = append(missingIds, id)
		}
	}

	if len(missingIds) > 0 {
		fps, err := s.store.GetMulti(ctx, missingIds)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to get fingerprints from store")
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
			return nil, status.Error(codes.Internal, fmt.Sprintf("failed to compare fingerprints"))
		}
		if score >= minScore {
			results = append(results, &pb.MatchingFingerprint{Id: id, Similarity: score})
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
		return nil, status.Error(codes.Internal, "failed to search index")
	}

	log.Debug().Int("candidates", len(candidateIds)).Msg("received candidates")

	startTime := time.Now()

	results, err := s.compareFingerprints(ctx, req.Fingerprint, candidateIds, req.MinScore)
	if err != nil {
		return nil, err
	}
	if len(results) > maxResults {
		results = results[:maxResults]
	}

	log.Debug().Dur("duration", time.Since(startTime)).Int("results", len(results)).Msg("search finished")

	return &pb.SearchFingerprintResponse{Results: results}, nil
}
