// Copyright (C) 2017  Lukas Lalinsky
// Distributed under the MIT license, see the LICENSE file for details.

package chromaprint

import (
	"math"
	"sort"
	"time"

	common_pb "github.com/acoustid/go-acoustid/proto/common"
	"github.com/acoustid/go-acoustid/util"
	"github.com/acoustid/go-acoustid/util/signal"
	"github.com/pkg/errors"
	"google.golang.org/protobuf/proto"
)

const NumQueryBits = 26
const NumAlignBits = 14
const NumUniqBits = 16
const NumOffsetCandidates = 3
const MaxOffsetThresholdDiv = 10

func hashBitMask(nbits int) uint32 {
	var mask uint32 = 0xaaaaaaaa
	if nbits <= 16 {
		mask &= (1 << (uint(nbits) * 2)) - 1
	} else {
		mask |= 0x55555555 & ((1 << (uint(nbits-16) * 2)) - 1)
	}
	return mask
}

func ExtractQuery(fp *common_pb.Fingerprint, numBits int) *common_pb.Fingerprint {
	mask := hashBitMask(numBits)
	query := &common_pb.Fingerprint{}
	proto.Merge(query, fp)
	for i, hash := range query.Hashes {
		query.Hashes[i] = hash & mask
	}
	return query
}

type FingerprintConfig struct {
	SampleRate            int
	FrameSize             int
	FrameOverlap          int
	MaxFilterWidth        int
	NumFilterCoefficients int
}

func (c FingerprintConfig) ItemDuration() time.Duration {
	duration := c.FrameSize - c.FrameOverlap
	return time.Microsecond * time.Duration(duration*1000000/c.SampleRate)
}

func (c FingerprintConfig) Delay() time.Duration {
	delay := (c.FrameSize-c.FrameOverlap)*((c.NumFilterCoefficients-1)+(c.MaxFilterWidth-1)) + c.FrameOverlap
	return time.Microsecond * time.Duration(delay*1000000/c.SampleRate)
}

func (c FingerprintConfig) Offset(i int) time.Duration {
	return c.ItemDuration() * time.Duration(i)
}

func (c FingerprintConfig) Duration(i int) time.Duration {
	if i == 0 {
		return time.Duration(0)
	}
	return c.Offset(i) + c.Delay()
}

var FingerprintConfigs = map[int]FingerprintConfig{
	1: {
		SampleRate:            11025,
		FrameSize:             4096,
		FrameOverlap:          4096 - 4096/3,
		NumFilterCoefficients: 5,
		MaxFilterWidth:        16,
	},
}

type MatchResult struct {
	Version      int
	Config       FingerprintConfig
	MasterLength int
	QueryLength  int
	Sections     []MatchingSection
}

func (mr MatchResult) Empty() bool {
	return len(mr.Sections) == 0
}

func (mr MatchResult) MatchingDuration() time.Duration {
	length := 0
	for _, s := range mr.Sections {
		length += s.End - s.Start
	}
	return mr.Config.Duration(length)
}

func (mr MatchResult) QueryOffset() time.Duration {
	if len(mr.Sections) == 0 {
		return time.Duration(0)
	}
	s := mr.Sections[0]
	if s.Offset < 0 {
		return mr.Config.Offset(s.Start - s.Offset)
	} else {
		return mr.Config.Offset(s.Start)
	}
}

func (mr MatchResult) QueryDuration() time.Duration {
	return mr.Config.Duration(mr.QueryLength)
}

func (mr MatchResult) MasterOffset() time.Duration {
	if len(mr.Sections) == 0 {
		return time.Duration(0)
	}
	s := mr.Sections[0]
	if s.Offset > 0 {
		return mr.Config.Offset(s.Start + s.Offset)
	} else {
		return mr.Config.Offset(s.Start)
	}
}

func (mr MatchResult) MasterDuration() time.Duration {
	return mr.Config.Duration(mr.MasterLength)
}

type MatchingSection struct {
	Offset int
	Start  int
	End    int
	Score  float64
}

var ErrInvalidFingerprintVersion = errors.New("invalid fingerprint version")

type FingerprintMatcher struct {
	NumQueryBits        int
	NumAlignBits        int
	MaxOffset           int
	MaxOffsetCandidates int
}

func NewFingerprintMatcher() *FingerprintMatcher {
	return &FingerprintMatcher{
		NumAlignBits:        14,
		MaxOffset:           80,
		MaxOffsetCandidates: 1,
	}
}

func (fm *FingerprintMatcher) Compare(master *common_pb.Fingerprint, query *common_pb.Fingerprint) (float64, error) {
	if master.Version != query.Version {
		return 0, ErrInvalidFingerprintVersion
	}
	_, exists := FingerprintConfigs[int(master.Version)]
	if !exists {
		return 0, ErrInvalidFingerprintVersion
	}

	if len(master.Hashes) >= 1<<16 {
		return 0, errors.New("master fingerprint too long")
	}
	if len(query.Hashes) >= 1<<16 {
		return 0, errors.New("query fingerprint too long")
	}

	offsetHits := AlignFingerprints(master, query, fm.NumAlignBits, fm.MaxOffsetCandidates, fm.MaxOffset)
	if len(offsetHits) == 0 {
		return 0, nil
	}

	score, err := CompareAlignedFingerprints(master, query, offsetHits[0])
	if err != nil {
		return 0, errors.WithMessage(err, "comparing failed")
	}

	return score, nil
}

func (fm *FingerprintMatcher) Match(master *common_pb.Fingerprint, query *common_pb.Fingerprint) (*MatchResult, error) {
	if master.Version != query.Version {
		return nil, ErrInvalidFingerprintVersion
	}
	config, exists := FingerprintConfigs[int(master.Version)]
	if !exists {
		return nil, ErrInvalidFingerprintVersion
	}

	if len(master.Hashes) >= 1<<16 {
		return nil, errors.New("master fingerprint too long")
	}
	if len(query.Hashes) >= 1<<16 {
		return nil, errors.New("query fingerprint too long")
	}

	result := &MatchResult{
		Version:      int(master.Version),
		Config:       config,
		MasterLength: len(master.Hashes),
		QueryLength:  len(query.Hashes),
	}

	offsetHits := AlignFingerprints(master, query, fm.NumAlignBits, fm.MaxOffsetCandidates, fm.MaxOffset)
	for _, hit := range offsetHits {
		sections, err := matchAlignedFingerprints(master, query, hit.Offset)
		if err != nil {
			return nil, errors.WithMessage(err, "matching failed")
		}
		if len(sections) > 0 {
			result.Sections = sections
			break
		}
	}

	return result, nil
}

func CompareFingerprints(master *common_pb.Fingerprint, query *common_pb.Fingerprint) (float64, error) {
	matcher := NewFingerprintMatcher()
	return matcher.Compare(master, query)
}

func MatchFingerprints(master *common_pb.Fingerprint, query *common_pb.Fingerprint) (*MatchResult, error) {
	matcher := NewFingerprintMatcher()
	return matcher.Match(master, query)
}

func matchAlignedFingerprints(master *common_pb.Fingerprint, query *common_pb.Fingerprint, offset int) ([]MatchingSection, error) {
	masterHashes := master.Hashes
	queryHashes := query.Hashes
	if offset >= 0 {
		masterHashes = masterHashes[offset:]
	} else {
		queryHashes = queryHashes[-offset:]
	}

	n := len(masterHashes)
	if n > len(queryHashes) {
		n = len(queryHashes)
	}

	diff := make([]float64, n)
	for i := 0; i < n; i++ {
		diff[i] = float64(util.PopCount32(masterHashes[i] ^ queryHashes[i]))
	}
	// log.Print(diff)

	smoothedDiff := make([]float64, n)
	signal.GaussianFilter(diff, smoothedDiff, 9, 1.3, signal.Border{Type: signal.BorderReflect})
	// log.Print(smoothedDiff)

	smoothedDiffGradient := make([]float64, n)
	signal.Gradient(smoothedDiff, smoothedDiffGradient)
	// log.Print(smoothedDiffGradient)

	edges := []int{0}
	for i := 1; i < n-1; i++ {
		x0 := math.Abs(smoothedDiffGradient[i-1])
		x1 := math.Abs(smoothedDiffGradient[i])
		x2 := math.Abs(smoothedDiffGradient[i+1])
		if x0 <= x1 && x2 < x1 {
			g := x1 / (1 + smoothedDiff[i]/4)
			if g > 0.5 {
				// log.Printf("peak %v %v %v", i, x1, g)
				edges = append(edges, i)
			}
		}
	}
	edges = append(edges, n)

	matches := make([]MatchingSection, 0, len(edges)-1)
	for i := 0; i < len(edges)-1; i++ {
		m := MatchingSection{offset, edges[i], edges[i+1], 0}
		for j := m.Start; j < m.End; j++ {
			m.Score += diff[j]
		}
		m.Score /= float64(m.End - m.Start)
		if m.Score < 13 {
			matches = append(matches, m)
		}
	}

	return matches, nil
}

type OffsetHit struct {
	Offset int
	Count  float64
}

func AlignFingerprints(master *common_pb.Fingerprint, query *common_pb.Fingerprint, numBits int, limit int, maxOffset int) []OffsetHit {
	mask := hashBitMask(numBits)

	type HashOffset struct {
		Hash   uint32
		Offset int
	}

	queryHashes := make([]HashOffset, 0, len(query.Hashes))
	for offset, hash := range query.Hashes {
		queryHashes = append(queryHashes, HashOffset{hash & mask, offset})
	}
	sort.Slice(queryHashes, func(i, j int) bool { return queryHashes[i].Hash < queryHashes[j].Hash })

	masterHashes := make([]HashOffset, 0, len(master.Hashes))
	for offset, hash := range master.Hashes {
		masterHashes = append(masterHashes, HashOffset{hash & mask, offset})
	}
	sort.Slice(masterHashes, func(i, j int) bool { return masterHashes[i].Hash < masterHashes[j].Hash })

	numCounts := len(masterHashes) + len(queryHashes) + 1
	counts := make([]float64, numCounts)
	i := 0
	for _, mo := range masterHashes {
		for i < len(queryHashes) && queryHashes[i].Hash < mo.Hash {
			i++
		}
		if i >= len(queryHashes) {
			break
		}
		for j := i; j < len(queryHashes) && queryHashes[j].Hash == mo.Hash; j++ {
			offset := mo.Offset - queryHashes[j].Offset
			if maxOffset == 0 || (-maxOffset <= offset && offset <= maxOffset) {
				offset += len(queryHashes)
				counts[offset] += 1
			}
		}
	}

	smoothedCounts := make([]float64, numCounts)
	signal.GaussianFilter(counts, smoothedCounts, 3, 1.3, signal.Border{Type: signal.BorderReflect})

	var topCount float64
	for _, c := range smoothedCounts {
		if c > topCount {
			topCount = c
		}
	}

	countThreshold := topCount / MaxOffsetThresholdDiv
	if countThreshold < 2 {
		countThreshold = 2
	}

	offsetHits := make([]OffsetHit, 0)
	for offset, count := range smoothedCounts {
		if count >= countThreshold {
			var previousCount, nextCount float64
			if offset > 0 {
				previousCount = smoothedCounts[offset-1]
			}
			if offset < len(smoothedCounts)-1 {
				nextCount = smoothedCounts[offset+1]
			}
			if previousCount <= count && nextCount < count {
				offsetHits = append(offsetHits, OffsetHit{offset - len(queryHashes), count})
			}
		}
	}
	sort.Slice(offsetHits, func(i, j int) bool { return offsetHits[i].Count >= offsetHits[j].Count })
	if len(offsetHits) > limit {
		offsetHits = offsetHits[:limit]
	}

	return offsetHits
}

func countUniqueHashes(hashes []uint32, numBits int) int {
	mask := hashBitMask(numBits)
	maskedHashes := make([]uint32, len(hashes))
	for i, hash := range hashes {
		maskedHashes[i] = hash & mask
	}
	sort.Slice(maskedHashes, func(i, j int) bool { return maskedHashes[i] < maskedHashes[j] })
	var uniqueCount int
	for _, hash := range maskedHashes {
		if uniqueCount == 0 || hash != maskedHashes[uniqueCount-1] {
			maskedHashes[uniqueCount] = hash
			uniqueCount++
		}
	}
	return uniqueCount
}

// This is supposed to calculate a single score similar to https://github.com/acoustid/pg_acoustid/blob/main/acoustid_compare.c#L122
// It's only used for legacy reasons and will be replaced in the future
func CompareAlignedFingerprints(a *common_pb.Fingerprint, b *common_pb.Fingerprint, offset OffsetHit) (float64, error) {
	ahashes := a.Hashes
	bhashes := b.Hashes

	asize := len(ahashes)
	bsize := len(bhashes)

	minSize := asize
	if bsize < minSize {
		minSize = bsize
	}
	if minSize == 0 {
		return 0.0, nil
	}

	if offset.Offset < 0 {
		bhashes = bhashes[-offset.Offset:]
		bsize = len(bhashes)
	} else {
		ahashes = ahashes[offset.Offset:]
		asize = len(ahashes)
	}

	size := asize
	if bsize < size {
		size = bsize
	}
	if size == 0 {
		return 0.0, nil
	}

	auniq := countUniqueHashes(ahashes, NumUniqBits)
	buniq := countUniqueHashes(bhashes, NumUniqBits)

	if offset.Count < float64(max(auniq, buniq))*0.02 {
		return 0.0, nil
	}

	diversity := min(
		min(1.0, float64(auniq+10)/float64(asize)+0.5),
		min(1.0, float64(buniq+10)/float64(bsize)+0.5))

	var bitError uint64
	for i := 0; i < size; i++ {
		bitError += uint64(util.PopCount32(ahashes[i] ^ bhashes[i]))
	}

	score := (float64(size) / float64(minSize)) * (1.0 - float64(bitError)/float64(size*32))
	if score < 0.0 {
		score = 0.0
	}
	if diversity < 1.0 {
		score = math.Pow(score, 8.0-7.0*diversity)
	}

	return score, nil
}
