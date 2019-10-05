package fingerprint_db

import (
	"testing"
	"context"
	"database/sql"

	_ "github.com/lib/pq"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestScoreSearchMatches(t *testing.T) {
	connStr := "user=acoustid password=acoustid dbname=acoustid_fingerprint_test host=127.0.0.1 port=15432 sslmode=disable"
	db, err := sql.Open("postgres", connStr)
	require.NoError(t, err)

	ctx := context.Background()

	fpDB := NewFingerprintDB(db)
	matches, err := fpDB.ScoreSearchMatches(ctx, []uint32{1,2,3}, []int{1})
	require.NoError(t, err)

	assert.Equal(t, matches, []ScoredSearchMatch{})
}
