package chromaprint

import "time"

// Fingerprint contains raw fingerprint data.
type Fingerprint struct {
	Version int      // version of the algorithm that generated the fingerprint
	Hashes  []uint32 // the fingerprint
}

// AudioFileFingerprint contains raw fingerprint data and duration of the audio file from which the fingerprint was taken.
type AudioFileFingerprint struct {
	Fingerprint
	Duration time.Duration
}
