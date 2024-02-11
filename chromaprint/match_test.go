// Copyright (C) 2017  Lukas Lalinsky
// Distributed under the MIT license, see the LICENSE file for details.

package chromaprint

import (
	"os"
	"path"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func loadTestFingerprint(t *testing.T, name string) *Fingerprint {
	data, err := os.ReadFile(path.Join("..", "testdata", name+".txt"))
	require.NoError(t, err)
	fp, err := ParseFingerprintString(string(data))
	require.NoError(t, err)
	return &fp
}

func TestMatchFingerprints_NoMatch(t *testing.T) {
	master := loadTestFingerprint(t, "calibre_sunrise")
	query := loadTestFingerprint(t, "radio1_1_ad")
	result, err := MatchFingerprints(master, query)
	if assert.NoError(t, err) {
		assert.Empty(t, result.Sections)
		assert.Equal(t, time.Duration(0), result.MatchingDuration())
	}
}

func TestMatchFingerprints_PartialMatch(t *testing.T) {
	master := loadTestFingerprint(t, "calibre_sunrise")
	query := loadTestFingerprint(t, "radio1_2_ad_and_calibre_sunshine")
	result, err := MatchFingerprints(master, query)
	if assert.NoError(t, err) {
		assert.NotEmpty(t, result.Sections)
		assert.Equal(t, "13.000046s", result.MatchingDuration().String())
	}
}

func TestMatchFingerprints_FullMatch1(t *testing.T) {
	master := loadTestFingerprint(t, "calibre_sunrise")
	query := loadTestFingerprint(t, "radio1_3_calibre_sunshine")
	result, err := MatchFingerprints(master, query)
	if assert.NoError(t, err) {
		assert.NotEmpty(t, result.Sections)
		assert.Equal(t, "17.580979s", result.MatchingDuration().String())
	}
}

func TestMatchFingerprints_FullMatch2(t *testing.T) {
	master := loadTestFingerprint(t, "calibre_sunrise")
	query := loadTestFingerprint(t, "radio1_4_calibre_sunshine")
	result, err := MatchFingerprints(master, query)
	if assert.NoError(t, err) {
		assert.NotEmpty(t, result.Sections)
		assert.Equal(t, "17.580979s", result.MatchingDuration().String())
	}
}

func TestMatchFingerprints_FullMatch3(t *testing.T) {
	master := loadTestFingerprint(t, "calibre_sunrise")
	query := loadTestFingerprint(t, "radio1_5_calibre_sunshine")
	result, err := MatchFingerprints(master, query)
	if assert.NoError(t, err) {
		assert.NotEmpty(t, result.Sections)
		assert.Equal(t, "17.580979s", result.MatchingDuration().String())
	}
}

func TestCompareFingerprints_NoMatch(t *testing.T) {
	master := loadTestFingerprint(t, "calibre_sunrise")
	query := loadTestFingerprint(t, "radio1_1_ad")
	score, err := CompareFingerprints(master, query)
	if assert.NoError(t, err) {
		assert.Equal(t, 0.0, score)
	}
}

func TestCompareFingerprints_FullMatch1(t *testing.T) {
	master := loadTestFingerprint(t, "calibre_sunrise")
	query := loadTestFingerprint(t, "radio1_3_calibre_sunshine")
	score, err := CompareFingerprints(master, query)
	if assert.NoError(t, err) {
		assert.InDelta(t, 0.9, score, 0.1)
	}
}

func TestCompareFingerprints_PartialMatch(t *testing.T) {
	master := loadTestFingerprint(t, "calibre_sunrise")
	query := loadTestFingerprint(t, "radio1_2_ad_and_calibre_sunshine")
	score, err := CompareFingerprints(master, query)
	if assert.NoError(t, err) {
		assert.InDelta(t, 0.7, score, 0.1)
	}
}
