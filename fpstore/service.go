package fpstore

import (
	"context"
	"log"
	"net"

	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type FingerprintStoreService struct {
	pb.UnimplementedFingerprintStoreServer
	store FingerprintStore
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

func NewFingerprintStoreService(store FingerprintStore, cache FingerprintCache) *FingerprintStoreService {
	return &FingerprintStoreService{store: store, cache: cache}
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

// Implement Get method
func (s *FingerprintStoreService) Get(ctx context.Context, req *pb.GetFingerprintRequest) (*pb.GetFingerprintResponse, error) {
	id := req.Id
	if id == 0 {
		return nil, status.Error(codes.InvalidArgument, "id is required")
	}
	fp, err := s.cache.Get(ctx, id)
	if err != nil {
		log.Printf("failed to get fingerprint from cache: %v", err)
	}
	if fp == nil {
		fp, err = s.store.Get(ctx, id)
		if err != nil {
			log.Printf("failed to get fingerprint from store: %v", err)
			return nil, status.Error(codes.Internal, "failed to get fingerprint")
		}
		if fp == nil {
			return nil, status.Error(codes.NotFound, "fingerprint not found")
		}
		s.cache.Set(ctx, id, fp)
	}
	return &pb.GetFingerprintResponse{Fingerprint: fp}, nil
}
