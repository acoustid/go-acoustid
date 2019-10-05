

SELECT pg_catalog.set_config('search_path', '', false);


CREATE EXTENSION IF NOT EXISTS acoustid WITH SCHEMA public;



COMMENT ON EXTENSION acoustid IS 'AcoustID utility functions';



CREATE EXTENSION IF NOT EXISTS intarray WITH SCHEMA public;



COMMENT ON EXTENSION intarray IS 'functions, operators, and index support for 1-D arrays of integers';





CREATE TABLE fingerprint (
    id integer NOT NULL,
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



CREATE SEQUENCE fingerprint_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE fingerprint_id_seq OWNED BY fingerprint.id;



CREATE TABLE foreignid (
    id integer NOT NULL,
    vendor_id integer NOT NULL,
    name text NOT NULL
);



CREATE SEQUENCE foreignid_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE foreignid_id_seq OWNED BY foreignid.id;



CREATE TABLE foreignid_vendor (
    id integer NOT NULL,
    name character varying NOT NULL
);



CREATE SEQUENCE foreignid_vendor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE foreignid_vendor_id_seq OWNED BY foreignid_vendor.id;



CREATE TABLE meta (
    id integer NOT NULL,
    track character varying,
    artist character varying,
    album character varying,
    album_artist character varying,
    track_no integer,
    disc_no integer,
    year integer
);



CREATE SEQUENCE meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE meta_id_seq OWNED BY meta.id;



CREATE TABLE track (
    id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    gid uuid NOT NULL,
    new_id integer
);



CREATE TABLE track_foreignid (
    id integer NOT NULL,
    track_id integer NOT NULL,
    foreignid_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL
);



CREATE SEQUENCE track_foreignid_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE track_foreignid_id_seq OWNED BY track_foreignid.id;



CREATE SEQUENCE track_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE track_id_seq OWNED BY track.id;



CREATE TABLE track_mbid (
    id integer NOT NULL,
    track_id integer NOT NULL,
    mbid uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL,
    disabled boolean DEFAULT false NOT NULL
);



CREATE SEQUENCE track_mbid_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE track_mbid_id_seq OWNED BY track_mbid.id;



CREATE TABLE track_meta (
    id integer NOT NULL,
    track_id integer NOT NULL,
    meta_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL
);



CREATE SEQUENCE track_meta_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE track_meta_id_seq OWNED BY track_meta.id;



CREATE TABLE track_puid (
    id integer NOT NULL,
    track_id integer NOT NULL,
    puid uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL
);



CREATE SEQUENCE track_puid_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE track_puid_id_seq OWNED BY track_puid.id;



ALTER TABLE ONLY fingerprint ALTER COLUMN id SET DEFAULT nextval('fingerprint_id_seq'::regclass);



ALTER TABLE ONLY foreignid ALTER COLUMN id SET DEFAULT nextval('foreignid_id_seq'::regclass);



ALTER TABLE ONLY foreignid_vendor ALTER COLUMN id SET DEFAULT nextval('foreignid_vendor_id_seq'::regclass);



ALTER TABLE ONLY meta ALTER COLUMN id SET DEFAULT nextval('meta_id_seq'::regclass);



ALTER TABLE ONLY track ALTER COLUMN id SET DEFAULT nextval('track_id_seq'::regclass);



ALTER TABLE ONLY track_foreignid ALTER COLUMN id SET DEFAULT nextval('track_foreignid_id_seq'::regclass);



ALTER TABLE ONLY track_mbid ALTER COLUMN id SET DEFAULT nextval('track_mbid_id_seq'::regclass);



ALTER TABLE ONLY track_meta ALTER COLUMN id SET DEFAULT nextval('track_meta_id_seq'::regclass);



ALTER TABLE ONLY track_puid ALTER COLUMN id SET DEFAULT nextval('track_puid_id_seq'::regclass);



ALTER TABLE ONLY fingerprint
    ADD CONSTRAINT fingerprint_pkey PRIMARY KEY (id);



ALTER TABLE ONLY foreignid
    ADD CONSTRAINT foreignid_pkey PRIMARY KEY (id);



ALTER TABLE ONLY foreignid_vendor
    ADD CONSTRAINT foreignid_vendor_pkey PRIMARY KEY (id);



ALTER TABLE ONLY meta
    ADD CONSTRAINT meta_pkey PRIMARY KEY (id);



ALTER TABLE ONLY track_foreignid
    ADD CONSTRAINT track_foreignid_pkey PRIMARY KEY (id);



ALTER TABLE ONLY track_mbid
    ADD CONSTRAINT track_mbid_pkey PRIMARY KEY (id);



ALTER TABLE ONLY track_meta
    ADD CONSTRAINT track_meta_pkey PRIMARY KEY (id);



ALTER TABLE ONLY track
    ADD CONSTRAINT track_pkey PRIMARY KEY (id);



ALTER TABLE ONLY track_puid
    ADD CONSTRAINT track_puid_pkey PRIMARY KEY (id);



CREATE INDEX fingerprint_idx_length ON fingerprint USING btree (length);



CREATE INDEX fingerprint_idx_track_id ON fingerprint USING btree (track_id);



CREATE INDEX foreignid_idx_vendor ON foreignid USING btree (vendor_id);



CREATE UNIQUE INDEX foreignid_idx_vendor_name ON foreignid USING btree (vendor_id, name);



CREATE UNIQUE INDEX foreignid_vendor_idx_name ON foreignid_vendor USING btree (name);



CREATE INDEX track_foreignid_idx_foreignid_id ON track_foreignid USING btree (foreignid_id);



CREATE UNIQUE INDEX track_foreignid_idx_track_id_foreignid ON track_foreignid USING btree (track_id, foreignid_id);



CREATE UNIQUE INDEX track_foreignid_idx_uniq ON track_foreignid USING btree (track_id, foreignid_id);



CREATE INDEX track_idx_gid ON track USING btree (gid);



CREATE INDEX track_idx_new_id ON track USING btree (new_id) WHERE (new_id IS NOT NULL);



CREATE INDEX track_mbid_idx_mbid ON track_mbid USING btree (mbid);



CREATE UNIQUE INDEX track_mbid_idx_track_id_mbid ON track_mbid USING btree (track_id, mbid);



CREATE UNIQUE INDEX track_mbid_idx_uniq ON track_mbid USING btree (track_id, mbid);



CREATE INDEX track_meta_idx_meta_id ON track_meta USING btree (meta_id);



CREATE UNIQUE INDEX track_meta_idx_track_id_meta ON track_meta USING btree (track_id, meta_id);



CREATE UNIQUE INDEX track_meta_idx_uniq ON track_meta USING btree (track_id, meta_id);



CREATE INDEX track_puid_idx_puid ON track_puid USING btree (puid);



CREATE UNIQUE INDEX track_puid_idx_track_id_puid ON track_puid USING btree (track_id, puid);



CREATE UNIQUE INDEX track_puid_idx_uniq ON track_puid USING btree (track_id, puid);

































































































































ALTER TABLE ONLY fingerprint
    ADD CONSTRAINT fingerprint_fk_track_id FOREIGN KEY (track_id) REFERENCES track(id);



ALTER TABLE ONLY foreignid
    ADD CONSTRAINT foreignid_fk_vendor_id FOREIGN KEY (vendor_id) REFERENCES foreignid_vendor(id);



ALTER TABLE ONLY track
    ADD CONSTRAINT track_fk_new_id FOREIGN KEY (new_id) REFERENCES track(id);



ALTER TABLE ONLY track_foreignid
    ADD CONSTRAINT track_foreignid_fk_foreignid_id FOREIGN KEY (foreignid_id) REFERENCES foreignid(id);



ALTER TABLE ONLY track_foreignid
    ADD CONSTRAINT track_foreignid_fk_track_id FOREIGN KEY (track_id) REFERENCES track(id);



ALTER TABLE ONLY track_mbid
    ADD CONSTRAINT track_mbid_fk_track_id FOREIGN KEY (track_id) REFERENCES track(id);



ALTER TABLE ONLY track_meta
    ADD CONSTRAINT track_meta_fk_meta_id FOREIGN KEY (meta_id) REFERENCES meta(id);



ALTER TABLE ONLY track_meta
    ADD CONSTRAINT track_meta_fk_track_id FOREIGN KEY (track_id) REFERENCES track(id);



ALTER TABLE ONLY track_puid
    ADD CONSTRAINT track_puid_fk_track_id FOREIGN KEY (track_id) REFERENCES track(id);



