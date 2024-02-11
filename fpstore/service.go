package fpstore

import (
	"context"
	"fmt"
	"log"
	"net"

	"github.com/acoustid/go-acoustid/chromaprint"
	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type FingerprintStoreService struct {
	pb.UnimplementedFingerprintStoreServer
	store FingerprintStore
	index FingerprintIndex
	cache FingerprintCache
}

func RunFingerprintStoreServer(listenAddr string, service pb.FingerprintStoreServer) error {
	server := grpc.NewServer()
	pb.RegisterFingerprintStoreServer(server, service)
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

func (s *FingerprintStoreService) compareFingerprints(ctx context.Context, a, b *pb.Fingerprint) (float64, error) {
	if len(a.Hashes) == 0 || len(b.Hashes) == 0 {
		return 0, nil
	}
	a2 := chromaprint.Fingerprint{Version: int(a.Version), Hashes: a.Hashes}
	b2 := chromaprint.Fingerprint{Version: int(b.Version), Hashes: b.Hashes}
	return chromaprint.CompareFingerprints(&a2, &b2)
}

// Implement Get method
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
	var resp pb.CompareFingerprintResponse
	for _, id := range req.Ids {
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
		score, err := s.compareFingerprints(ctx, req.Fingerprint, fp)
		resp.Results = append(resp.Results, &pb.MatchingFingerprint{Id: id, Similarity: float32(score)})
	}
	return &resp, nil
}
