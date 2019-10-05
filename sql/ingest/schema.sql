

SELECT pg_catalog.set_config('search_path', '', false);




CREATE TABLE fingerprint_source (
    id integer NOT NULL,
    fingerprint_id integer NOT NULL,
    submission_id integer NOT NULL,
    source_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);



CREATE SEQUENCE fingerprint_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE fingerprint_source_id_seq OWNED BY fingerprint_source.id;



CREATE TABLE submission (
    id integer NOT NULL,
    fingerprint integer[] NOT NULL,
    length smallint NOT NULL,
    bitrate smallint,
    format_id integer,
    created timestamp with time zone DEFAULT now() NOT NULL,
    source_id integer NOT NULL,
    mbid uuid,
    handled boolean DEFAULT false,
    puid uuid,
    meta_id integer,
    foreignid_id integer,
    CONSTRAINT submission_bitrate_check CHECK ((bitrate > 0)),
    CONSTRAINT submission_length_check CHECK ((length > 0))
);



CREATE SEQUENCE submission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE submission_id_seq OWNED BY submission.id;



CREATE TABLE track_foreignid_source (
    id integer NOT NULL,
    track_foreignid_id integer NOT NULL,
    submission_id integer NOT NULL,
    source_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);



CREATE SEQUENCE track_foreignid_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE track_foreignid_source_id_seq OWNED BY track_foreignid_source.id;



CREATE TABLE track_mbid_change (
    id integer NOT NULL,
    track_mbid_id integer NOT NULL,
    account_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    disabled boolean NOT NULL,
    note text
);



CREATE SEQUENCE track_mbid_change_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE track_mbid_change_id_seq OWNED BY track_mbid_change.id;



CREATE TABLE track_mbid_source (
    id integer NOT NULL,
    track_mbid_id integer NOT NULL,
    submission_id integer,
    source_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);



CREATE SEQUENCE track_mbid_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE track_mbid_source_id_seq OWNED BY track_mbid_source.id;



CREATE TABLE track_meta_source (
    id integer NOT NULL,
    track_meta_id integer NOT NULL,
    submission_id integer NOT NULL,
    source_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);



CREATE SEQUENCE track_meta_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE track_meta_source_id_seq OWNED BY track_meta_source.id;



CREATE TABLE track_puid_source (
    id integer NOT NULL,
    track_puid_id integer NOT NULL,
    submission_id integer NOT NULL,
    source_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);



CREATE SEQUENCE track_puid_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE track_puid_source_id_seq OWNED BY track_puid_source.id;



ALTER TABLE ONLY fingerprint_source ALTER COLUMN id SET DEFAULT nextval('fingerprint_source_id_seq'::regclass);



ALTER TABLE ONLY submission ALTER COLUMN id SET DEFAULT nextval('submission_id_seq'::regclass);



ALTER TABLE ONLY track_foreignid_source ALTER COLUMN id SET DEFAULT nextval('track_foreignid_source_id_seq'::regclass);



ALTER TABLE ONLY track_mbid_change ALTER COLUMN id SET DEFAULT nextval('track_mbid_change_id_seq'::regclass);



ALTER TABLE ONLY track_mbid_source ALTER COLUMN id SET DEFAULT nextval('track_mbid_source_id_seq'::regclass);



ALTER TABLE ONLY track_meta_source ALTER COLUMN id SET DEFAULT nextval('track_meta_source_id_seq'::regclass);



ALTER TABLE ONLY track_puid_source ALTER COLUMN id SET DEFAULT nextval('track_puid_source_id_seq'::regclass);



ALTER TABLE ONLY fingerprint_source
    ADD CONSTRAINT fingerprint_source_pkey PRIMARY KEY (id);



ALTER TABLE ONLY submission
    ADD CONSTRAINT submission_pkey PRIMARY KEY (id);



ALTER TABLE ONLY track_foreignid_source
    ADD CONSTRAINT track_foreignid_source_pkey PRIMARY KEY (id);



ALTER TABLE ONLY track_mbid_change
    ADD CONSTRAINT track_mbid_change_pkey PRIMARY KEY (id);



ALTER TABLE ONLY track_mbid_source
    ADD CONSTRAINT track_mbid_source_pkey PRIMARY KEY (id);



ALTER TABLE ONLY track_meta_source
    ADD CONSTRAINT track_meta_source_pkey PRIMARY KEY (id);



ALTER TABLE ONLY track_puid_source
    ADD CONSTRAINT track_puid_source_pkey PRIMARY KEY (id);



CREATE INDEX fingerprint_source_idx_submission_id ON fingerprint_source USING btree (submission_id);



CREATE INDEX submission_idx_handled ON submission USING btree (id) WHERE (handled = false);



CREATE INDEX track_mbid_change_idx_track_mbid_id ON track_mbid_change USING btree (track_mbid_id);



CREATE INDEX track_mbid_source_idx_track_mbid_id ON track_mbid_source USING btree (track_mbid_id);























































































