package chromaprint

import (
	"time"

	common_pb "github.com/acoustid/go-acoustid/proto/common"
)

// AudioFileFingerprint contains raw fingerprint data and duration of the audio file from which the fingerprint was taken.
type AudioFileFingerprint struct {
	Fingerprint *common_pb.Fingerprint
	Duration    time.Duration
}
