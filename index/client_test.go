package index

import (
	"bufio"
	"context"
	"net"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func MockIndexServer(t *testing.T, conn net.Conn, responses map[string]string) {
	defer conn.Close()

	reader := bufio.NewReader(conn)
	writer := bufio.NewWriter(conn)

	for {
		request, err := ReadLine(reader)
		require.Nil(t, err)

		response, exists := responses[request]
		if exists {
			WriteLine(writer, response)
		} else {
			require.Fail(t, "received unknown request: %v", request)
		}
	}
}

func TestIndexClient(t *testing.T) {
	server, client := net.Pipe()

	idx := NewIndexClient(client)
	defer idx.Close()

	responses := map[string]string{
		"echo":                          "OK ",
		"begin":                         "OK ",
		"commit":                        "OK ",
		"rollback":                      "OK ",
		"get attribute foo":             "OK bar",
		"set attribute foo baz":         "OK ",
		"insert 1 100,200,300":          "OK ",
		"insert 2 400,500,600":          "OK ",
		"get attribute max_document_id": "OK 2",
	}

	go MockIndexServer(t, server, responses)

	ctx := context.Background()

	err := idx.Ping(ctx)
	assert.Nil(t, err, "got error from idx.Ping()")

	value, err := idx.GetAttribute(ctx, "foo")
	assert.Nil(t, err, "got error from idx.GetAttribute()")
	assert.Equal(t, value, "bar")

	err = idx.SetAttribute(ctx, "foo", "baz")
	assert.Nil(t, err, "got error from idx.SetAttribute()")

	tx, err := idx.BeginTx(ctx)
	assert.Nil(t, err, "got error from idx.BeginTx()")

	err = tx.Insert(ctx, 1, []uint32{100, 200, 300})
	assert.Nil(t, err, "got error from tx.Insert()")

	err = tx.Commit(ctx)
	assert.Nil(t, err, "got error from tx.Commit()")

	tx2, err := idx.BeginTx(ctx)
	assert.Nil(t, err, "got error from idx.BeginTx()")

	err = tx2.Rollback(ctx)
	assert.Nil(t, err, "got error from tx2.Rollback()")

	var fingerprints []FingerprintInfo
	fingerprints = append(fingerprints, FingerprintInfo{ID: 1, Hashes: []uint32{100, 200, 300}})
	fingerprints = append(fingerprints, FingerprintInfo{ID: 2, Hashes: []uint32{400, 500, 600}})
	err = idx.Insert(ctx, fingerprints)
	assert.Nil(t, err, "got error from idx.BatchInsert()")

	id, err := idx.GetLastFingerprintID(ctx)
	assert.Nil(t, err, "got error from idx.GetAttribute()")
	assert.Equal(t, id, uint32(2))
}
