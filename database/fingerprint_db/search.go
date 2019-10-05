package fingerprint_db

import (
	"context"
	"github.com/lib/pq"
)

type ScoredSearchMatch struct {
	FingerprintID int
	TrackID       int
	Score         float64
}

func (s *FingerprintDB) ScoreSearchMatches(ctx context.Context, hashes []uint32, candidateIDs []int) ([]ScoredSearchMatch, error) {
	query := `
SELECT fingerprint_id, track_id, score
FROM (
	SELECT id AS fingerprint_id, track_id, acoustid_compare2(fingerprint, $1) AS score
	FROM fingerprint
	WHERE id = any($2)
) matches
ORDER BY score DESC
`
	rows, err := s.db.QueryContext(ctx, query, Uint32Array(hashes), pq.Array(candidateIDs))
	if err != nil {
		return nil, err
	}
	matches := []ScoredSearchMatch{}
	for rows.Next() {
		var match ScoredSearchMatch
		err = rows.Scan(&match.FingerprintID, &match.TrackID, &match.Score)
		if err != nil {
			return nil, err
		}
		matches = append(matches, match)
	}
	return matches, nil
}
