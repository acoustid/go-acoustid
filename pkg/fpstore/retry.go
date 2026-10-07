package fpstore

import (
	"context"
	"database/sql/driver"
	"errors"
	"io"
	"net"
	"time"

	"github.com/lib/pq"
	"github.com/rs/zerolog"
)

// How hard we try to ride out a lost database connection. A Patroni switchover
// resolves in seconds and this is the lookup path, so the budget is deliberately
// tiny: three attempts spread over 150ms. Waiting longer would turn a fast error
// into a slow one, which on a lookup is its own kind of outage.
const (
	maxDatabaseAttempts    = 3
	databaseRetryBaseDelay = 50 * time.Millisecond
)

// retryOnConnectionError runs an idempotent database operation, retrying it if
// it fails because the connection to the server went away.
//
// Only pass idempotent statements. A retried INSERT that had in fact committed
// before the connection dropped would be applied twice, and no error the caller
// sees can tell those two cases apart.
func retryOnConnectionError(ctx context.Context, op func() error) error {
	delay := databaseRetryBaseDelay
	for attempt := 1; ; attempt++ {
		err := op()
		if err == nil || attempt >= maxDatabaseAttempts || !isConnectionError(err) {
			return err
		}
		zerolog.Ctx(ctx).Warn().Err(err).Int("attempt", attempt).
			Msg("lost database connection, retrying")
		select {
		case <-ctx.Done():
			// Report what actually went wrong rather than the cancellation that
			// stopped us waiting on it.
			return err
		case <-time.After(delay):
		}
		delay *= 2
	}
}

// isConnectionError reports whether err means we lost the connection to the
// database, as opposed to the database rejecting the query.
//
// Only the first kind is worth another attempt. Retrying a statement timeout or
// a constraint violation would convert a visible fault into an invisible one,
// which is worse than the bug this is fixing.
func isConnectionError(err error) bool {
	if err == nil {
		return false
	}

	// The caller has already given up or run out of time; another attempt can
	// only make it slower to tell them so.
	if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		return false
	}

	// database/sql retries this one itself, but immediately and without ever
	// pausing, so during a failover all of its attempts land in the same broken
	// window. Reaching us means those were used up.
	if errors.Is(err, driver.ErrBadConn) {
		return true
	}

	// lib/pq turns a connection that closed between statements into an EOF.
	if errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) {
		return true
	}

	var opErr *net.OpError
	if errors.As(err, &opErr) {
		// A read that timed out is not a lost connection. It usually means the
		// server is slow, and retrying adds load to something already
		// struggling. The index client draws the same distinction.
		return !opErr.Timeout()
	}

	// Connection-lifecycle SQLSTATEs. Anything else pq reports is the server
	// answering us, and a second attempt would get the same answer.
	var pqErr *pq.Error
	if errors.As(err, &pqErr) {
		switch pqErr.Code {
		case "08000", // connection_exception
			"08001", // sqlclient_unable_to_establish_sqlconnection
			"08003", // connection_does_not_exist
			"08004", // sqlserver_rejected_establishment_of_sqlconnection
			"08006", // connection_failure
			"57P01", // admin_shutdown, "terminating connection due to administrator command"
			"57P02", // crash_shutdown
			"57P03": // cannot_connect_now, the server is still coming up
			return true
		}
		return false
	}

	return false
}
