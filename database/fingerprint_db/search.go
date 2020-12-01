package fingerprint_db

import (
	"context"
	"log"
	"math"
	"time"

	"github.com/lib/pq"
)

type ScoredSearchMatch struct {
	FingerprintID int
	TrackID       int
	TrackGID      string
	Score         float64
}

func (s *FingerprintDB) ScoreSearchMatches(ctx context.Context, hashes []uint32, candidateIDs []int, duration time.Duration) ([]ScoredSearchMatch, error) {
	txn, err := s.db.BeginTx(ctx, nil)
	defer txn.Rollback()

	if deadline, ok := ctx.Deadline(); ok {
		statementTimeout := time.Now().Sub(deadline) * 99 / 100
		if statementTimeout > 0 {
			txn.ExecContext(ctx, `SET LOCAL statement_timeout = ?`, statementTimeout)
		}
	}

	minDurationSecs := int(math.Round(duration.Seconds() - 7))
	maxDurationSecs := minDurationSecs + 14
	log.Printf("%v %v", minDurationSecs, maxDurationSecs)

	query := `
SELECT fingerprint_id, track_id, track.gid AS track_gid, score
FROM (
	SELECT id AS fingerprint_id, track_id, acoustid_compare2(fingerprint, $1) AS score
	FROM fingerprint
	WHERE
		id = any($2)
		AND length BETWEEN $3 AND $4
) matches
JOIN track ON matches.track_id = track.id
ORDER BY score DESC
`
	rows, err := txn.QueryContext(ctx, query, Uint32Array(hashes), pq.Array(candidateIDs), minDurationSecs, maxDurationSecs)
	if err != nil {
		return nil, err
	}
	matches := []ScoredSearchMatch{}
	for rows.Next() {
		var match ScoredSearchMatch
		err = rows.Scan(&match.FingerprintID, &match.TrackID, &match.TrackGID, &match.Score)
		if err != nil {
			return nil, err
		}
		matches = append(matches, match)
	}
	return matches, nil
}
