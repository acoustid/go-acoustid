CREATE TABLE fingerprint (
    id serial PRIMARY KEY,
    created timestamp with time zone DEFAULT now() NOT NULL,
    fingerprint integer[] NOT NULL,
    length integer NOT NULL,
    bitrate integer,
    format_id integer,
    track_id integer NOT NULL,
    submission_count integer NOT NULL,
    CONSTRAINT fingerprint_bitrate_check CHECK ((bitrate > 0)),
    CONSTRAINT fingerprint_length_check CHECK ((length > 0))
);

CREATE TABLE track (
    id serial PRIMARY KEY,
    created timestamp with time zone DEFAULT now() NOT NULL,
    gid uuid NOT NULL,
    new_id integer
);

CREATE TABLE track_mbid (
    id serial PRIMARY KEY,
    track_id integer NOT NULL,
    mbid uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL,
    disabled boolean DEFAULT false NOT NULL
);

CREATE TABLE track_puid (
    id serial PRIMARY KEY,
    track_id integer NOT NULL,
    puid uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL
);

CREATE TABLE track_foreignid (
    id serial PRIMARY KEY,
    track_id integer NOT NULL,
    foreignid_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL
);

CREATE TABLE track_meta (
    id serial PRIMARY KEY,
    track_id integer NOT NULL,
    meta_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL
);

CREATE INDEX fingerprint_idx_length ON fingerprint USING btree (length);
CREATE INDEX fingerprint_idx_track_id ON fingerprint USING btree (track_id);

CREATE INDEX track_idx_gid ON track USING btree (gid);
CREATE INDEX track_idx_new_id ON track USING btree (new_id) WHERE new_id IS NOT NULL;

CREATE UNIQUE INDEX track_mbid_idx_track_id_mbid ON track_mbid (track_id, mbid);

CREATE UNIQUE INDEX track_puid_idx_track_id_puid ON track_puid (track_id, puid);

CREATE UNIQUE INDEX track_foreignid_idx_track_id_foreignid ON track_foreignid (track_id, foreignid_id);

CREATE UNIQUE INDEX track_meta_idx_track_id_meta ON track_meta (track_id, meta_id);
