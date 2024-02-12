package fpstore

import (
	pb "github.com/acoustid/go-acoustid/proto/fpstore"
	"github.com/klauspost/compress/zstd"
	"google.golang.org/protobuf/proto"
)

func CompressEncodedFingerprint(data []byte) ([]byte, error) {
	enc, err := zstd.NewWriter(nil, zstd.WithEncoderLevel(zstd.SpeedFastest))
	if err != nil {
		return nil, err
	}
	defer enc.Close()
	return enc.EncodeAll(data, nil), nil
}

func UncompressEncodedFingerprint(data []byte) ([]byte, error) {
	dec, err := zstd.NewReader(nil)
	if err != nil {
		return nil, err
	}
	defer dec.Close()
	return dec.DecodeAll(data, nil)
}

func EncodeFingerprint(fp *pb.Fingerprint) ([]byte, error) {
	data, err := proto.Marshal(fp)
	if err != nil {
		return nil, err
	}
	return CompressEncodedFingerprint(data)
}

func DecodeFingerprint(data []byte) (*pb.Fingerprint, error) {
	data, err := UncompressEncodedFingerprint(data)
	if err != nil {
		return nil, err
	}
	fp := &pb.Fingerprint{}
	err = proto.Unmarshal(data, fp)
	if err != nil {
		return nil, err
	}
	return fp, nil
}
