package publicdata

type QueryContext struct {
	StartTime string
	EndTime   string
}

const ExportFingerprintUpdateQuery = `
SELECT id, fingerprint, length, created
FROM fingerprint
WHERE created >= '{{.StartTime}}' AND created < '{{.EndTime}}'
`

const ExportMetaUpdateQuery = `
SELECT id, track, artist, album, album_artist, track_no, disc_no, year, created
FROM meta
WHERE created >= '{{.StartTime}}' AND created < '{{.EndTime}}'
`

const ExportTrackUpdateQuery = `
SELECT id, gid, new_id, created, updated
FROM track
WHERE
  (created >= '{{.StartTime}}' AND created < '{{.EndTime}}')
  OR
  (updated >= '{{.StartTime}}' AND updated < '{{.EndTime}}')
`

const ExportTrackFingerprintUpdateQuery = `
SELECT id, track_id, id AS fingerprint_id, submission_count, created, updated
FROM fingerprint
WHERE
  (created >= '{{.StartTime}}' AND created < '{{.EndTime}}')
  OR
  (updated >= '{{.StartTime}}' AND updated < '{{.EndTime}}')
`

const ExportTrackMbidUpdateQuery = `
SELECT id, track_id, mbid, submission_count, nullif(disabled, false) AS disabled, created, updated
FROM track_mbid
WHERE
  (created >= '{{.StartTime}}' AND created < '{{.EndTime}}')
  OR
  (updated >= '{{.StartTime}}' AND updated < '{{.EndTime}}')
`

const ExportTrackPuidUpdateQuery = `
SELECT id, track_id, puid, submission_count, created, updated
FROM track_puid
WHERE
  (created >= '{{.StartTime}}' AND created < '{{.EndTime}}')
  OR
  (updated >= '{{.StartTime}}' AND updated < '{{.EndTime}}')
`

const ExportTrackMetaUpdateQuery = `
SELECT id, track_id, meta_id, submission_count, created, updated
FROM track_meta
WHERE
  (created >= '{{.StartTime}}' AND created < '{{.EndTime}}')
  OR
  (updated >= '{{.StartTime}}' AND updated < '{{.EndTime}}')
`
