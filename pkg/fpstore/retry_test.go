package fpstore

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"syscall"
	"testing"

	"github.com/lib/pq"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// severedConnection is what lib/pq hands back when the server end of a pooled
// connection goes away mid-query, which is what a Patroni switchover or a
// pgbouncer restart does to every connection at once.
func severedConnection() error {
	return &net.OpError{Op: "read", Net: "tcp", Err: syscall.ECONNRESET}
}

func adminShutdown() error {
	return &pq.Error{
		Severity: "FATAL",
		Code:     "57P01",
		Message:  "terminating connection due to administrator command",
	}
}

func statementTimeout() error {
	return &pq.Error{
		Severity: "ERROR",
		Code:     "57014",
		Message:  "canceling statement due to statement timeout",
	}
}

// scriptedDB is a database/sql driver whose failures are written in advance, so
// a lost connection can be tested without a Postgres to lose it to. errs is
// consumed one entry per statement; once it runs out, statements succeed and
// return value as their single column. repeat overrides all of that and fails
// every statement, for checking that retries stay bounded.
type scriptedDB struct {
	errs    []error
	repeat  error
	value   driver.Value
	queries int
}

func (d *scriptedDB) next() error {
	d.queries++
	if d.repeat != nil {
		return d.repeat
	}
	if d.queries <= len(d.errs) {
		return d.errs[d.queries-1]
	}
	return nil
}

func (d *scriptedDB) Connect(context.Context) (driver.Conn, error) {
	return &scriptedConn{db: d}, nil
}

func (d *scriptedDB) Driver() driver.Driver { return scriptedDriver{} }

func (d *scriptedDB) open() *sql.DB { return sql.OpenDB(d) }

type scriptedDriver struct{}

func (scriptedDriver) Open(string) (driver.Conn, error) {
	return nil, errors.New("scriptedDriver is only reachable through sql.OpenDB")
}

type scriptedConn struct{ db *scriptedDB }

func (c *scriptedConn) Prepare(string) (driver.Stmt, error) {
	return nil, errors.New("scriptedConn does not support prepared statements")
}

func (c *scriptedConn) Close() error              { return nil }
func (c *scriptedConn) Begin() (driver.Tx, error) { return nil, errors.New("no transactions") }

func (c *scriptedConn) QueryContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Rows, error) {
	if err := c.db.next(); err != nil {
		return nil, err
	}
	return &scriptedRows{value: c.db.value}, nil
}

func (c *scriptedConn) ExecContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Result, error) {
	if err := c.db.next(); err != nil {
		return nil, err
	}
	return driver.RowsAffected(1), nil
}

type scriptedRows struct {
	value driver.Value
	done  bool
}

func (r *scriptedRows) Columns() []string { return []string{"value"} }
func (r *scriptedRows) Close() error      { return nil }

func (r *scriptedRows) Next(dest []driver.Value) error {
	if r.done {
		return io.EOF
	}
	r.done = true
	dest[0] = r.value
	return nil
}

func TestGetRetriesAfterSeveredConnection(t *testing.T) {
	script := &scriptedDB{errs: []error{severedConnection()}, value: []byte("{1,2,3}")}
	store := NewPostgresFingerprintStore(script.open())

	fp, err := store.Get(context.Background(), 1)
	require.NoError(t, err)
	require.NotNil(t, fp)
	assert.Equal(t, []uint32{1, 2, 3}, fp.Hashes)
	assert.Equal(t, 2, script.queries, "the lookup should have been attempted twice")
}

func TestGetRetriesAfterAdminShutdown(t *testing.T) {
	script := &scriptedDB{errs: []error{adminShutdown()}, value: []byte("{1,2,3}")}
	store := NewPostgresFingerprintStore(script.open())

	fp, err := store.Get(context.Background(), 1)
	require.NoError(t, err)
	require.NotNil(t, fp)
	assert.Equal(t, []uint32{1, 2, 3}, fp.Hashes)
	assert.Equal(t, 2, script.queries, "the lookup should have been attempted twice")
}

func TestGetDoesNotRetryStatementTimeout(t *testing.T) {
	script := &scriptedDB{repeat: statementTimeout(), value: []byte("{1,2,3}")}
	store := NewPostgresFingerprintStore(script.open())

	_, err := store.Get(context.Background(), 1)
	require.Error(t, err)
	assert.Equal(t, 1, script.queries, "a statement timeout is the server answering, not a lost connection")
}

func TestGetGivesUpAfterMaxAttempts(t *testing.T) {
	script := &scriptedDB{repeat: severedConnection(), value: []byte("{1,2,3}")}
	store := NewPostgresFingerprintStore(script.open())

	_, err := store.Get(context.Background(), 1)
	require.Error(t, err)
	assert.Equal(t, maxDatabaseAttempts, script.queries)
}

func TestDeleteRetriesAfterSeveredConnection(t *testing.T) {
	// The first statement is the v1 existence check; the DELETE is the second.
	script := &scriptedDB{errs: []error{nil, severedConnection()}, value: int64(0)}
	store := NewPostgresFingerprintStore(script.open())

	require.NoError(t, store.Delete(context.Background(), 1))
	assert.Equal(t, 3, script.queries, "the DELETE should have been attempted twice")
}

func TestRetryOnConnectionErrorStopsWhenContextIsDone(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	attempts := 0
	err := retryOnConnectionError(ctx, func() error {
		attempts++
		return severedConnection()
	})

	require.Error(t, err)
	assert.Equal(t, 1, attempts, "a cancelled request should not wait around for another attempt")
}

func TestIsConnectionError(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{"nil", nil, false},
		{"severed connection", severedConnection(), true},
		{"connection refused", &net.OpError{Op: "dial", Net: "tcp", Err: syscall.ECONNREFUSED}, true},
		{"broken pipe", &net.OpError{Op: "write", Net: "tcp", Err: syscall.EPIPE}, true},
		{"bad connection", driver.ErrBadConn, true},
		{"eof", io.EOF, true},
		{"unexpected eof", io.ErrUnexpectedEOF, true},
		{"wrapped severed connection", fmt.Errorf("get fingerprint: %w", severedConnection()), true},
		{"admin shutdown", adminShutdown(), true},
		{"crash shutdown", &pq.Error{Code: "57P02"}, true},
		{"cannot connect now", &pq.Error{Code: "57P03"}, true},
		{"connection failure", &pq.Error{Code: "08006"}, true},
		{"statement timeout", statementTimeout(), false},
		{"unique violation", &pq.Error{Code: "23505"}, false},
		{"read only transaction", &pq.Error{Code: "25006"}, false},
		{"io timeout", &net.OpError{Op: "read", Net: "tcp", Err: os.ErrDeadlineExceeded}, false},
		{"context cancelled", context.Canceled, false},
		{"context deadline exceeded", context.DeadlineExceeded, false},
		{"no rows", sql.ErrNoRows, false},
		{"plain error", errors.New("boom"), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, isConnectionError(tt.err))
		})
	}
}
