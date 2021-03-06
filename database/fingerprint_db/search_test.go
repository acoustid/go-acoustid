package fingerprint_db

import (
	"context"
	"database/sql"
	"os"
	"testing"
	"time"

	"github.com/acoustid/go-acoustid/common"

	"github.com/DATA-DOG/go-txdb"
	_ "github.com/lib/pq"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestScoreSearchMatches(t *testing.T) {
	db, err := sql.Open("fingerprint_db_tx", t.Name())
	require.NoError(t, err)

	err = db.Ping()
	require.NoError(t, err)

	ctx := context.Background()

	fpDB := NewFingerprintDB(db)
	matches, err := fpDB.ScoreSearchMatches(ctx, []uint32{1, 2, 3}, []int{1}, time.Minute)
	require.NoError(t, err)

	assert.Equal(t, matches, []ScoredSearchMatch{})
}

func TestMain(m *testing.M) {
	cfg := common.NewTestDatabaseConfig("acoustid_fingerprint_test")
	txdb.Register("fingerprint_db_tx", "postgres", cfg.URL().String())

	exitCode := m.Run()
	os.Exit(exitCode)
}
