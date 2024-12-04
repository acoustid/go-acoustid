

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS acoustid WITH SCHEMA public;






CREATE EXTENSION IF NOT EXISTS intarray WITH SCHEMA public;





SET default_tablespace = '';

SET default_with_oids = false;


CREATE TABLE public.fingerprint (
    id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    fingerprint integer[] NOT NULL,
    length integer NOT NULL,
    bitrate integer,
    format_id integer,
    track_id integer NOT NULL,
    submission_count integer NOT NULL,
    updated timestamp with time zone,
    CONSTRAINT fingerprint_bitrate_check CHECK ((bitrate > 0)),
    CONSTRAINT fingerprint_length_check CHECK ((length > 0))
);



CREATE SEQUENCE public.fingerprint_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.fingerprint_id_seq OWNED BY public.fingerprint.id;



CREATE TABLE public.foreignid (
    id integer NOT NULL,
    vendor_id integer NOT NULL,
    name text NOT NULL
);



CREATE SEQUENCE public.foreignid_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.foreignid_id_seq OWNED BY public.foreignid.id;



CREATE TABLE public.foreignid_vendor (
    id integer NOT NULL,
    name character varying NOT NULL
);



CREATE SEQUENCE public.foreignid_vendor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.foreignid_vendor_id_seq OWNED BY public.foreignid_vendor.id;



CREATE TABLE public.meta (
    id integer NOT NULL,
    track character varying,
    artist character varying,
    album character varying,
    album_artist character varying,
    track_no integer,
    disc_no integer,
    year integer,
    created timestamp with time zone DEFAULT now() NOT NULL
);



CREATE SEQUENCE public.meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.meta_id_seq OWNED BY public.meta.id;



CREATE TABLE public.track (
    id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    gid uuid NOT NULL,
    new_id integer,
    updated timestamp with time zone
);



CREATE TABLE public.track_foreignid (
    id integer NOT NULL,
    track_id integer NOT NULL,
    foreignid_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL
);



CREATE SEQUENCE public.track_foreignid_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.track_foreignid_id_seq OWNED BY public.track_foreignid.id;



CREATE SEQUENCE public.track_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.track_id_seq OWNED BY public.track.id;



CREATE TABLE public.track_mbid (
    id integer NOT NULL,
    track_id integer NOT NULL,
    mbid uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL,
    disabled boolean DEFAULT false NOT NULL,
    updated timestamp with time zone
);



CREATE SEQUENCE public.track_mbid_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.track_mbid_id_seq OWNED BY public.track_mbid.id;



CREATE TABLE public.track_meta (
    id integer NOT NULL,
    track_id integer NOT NULL,
    meta_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL,
    updated timestamp with time zone
);



CREATE SEQUENCE public.track_meta_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.track_meta_id_seq OWNED BY public.track_meta.id;



CREATE TABLE public.track_puid (
    id integer NOT NULL,
    track_id integer NOT NULL,
    puid uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL,
    updated timestamp with time zone
);



CREATE SEQUENCE public.track_puid_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.track_puid_id_seq OWNED BY public.track_puid.id;



ALTER TABLE ONLY public.fingerprint ALTER COLUMN id SET DEFAULT nextval('public.fingerprint_id_seq'::regclass);



ALTER TABLE ONLY public.foreignid ALTER COLUMN id SET DEFAULT nextval('public.foreignid_id_seq'::regclass);



ALTER TABLE ONLY public.foreignid_vendor ALTER COLUMN id SET DEFAULT nextval('public.foreignid_vendor_id_seq'::regclass);



ALTER TABLE ONLY public.meta ALTER COLUMN id SET DEFAULT nextval('public.meta_id_seq'::regclass);



ALTER TABLE ONLY public.track ALTER COLUMN id SET DEFAULT nextval('public.track_id_seq'::regclass);



ALTER TABLE ONLY public.track_foreignid ALTER COLUMN id SET DEFAULT nextval('public.track_foreignid_id_seq'::regclass);



ALTER TABLE ONLY public.track_mbid ALTER COLUMN id SET DEFAULT nextval('public.track_mbid_id_seq'::regclass);



ALTER TABLE ONLY public.track_meta ALTER COLUMN id SET DEFAULT nextval('public.track_meta_id_seq'::regclass);



ALTER TABLE ONLY public.track_puid ALTER COLUMN id SET DEFAULT nextval('public.track_puid_id_seq'::regclass);



ALTER TABLE ONLY public.fingerprint
    ADD CONSTRAINT fingerprint_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.foreignid
    ADD CONSTRAINT foreignid_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.foreignid_vendor
    ADD CONSTRAINT foreignid_vendor_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.meta
    ADD CONSTRAINT meta_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.track_foreignid
    ADD CONSTRAINT track_foreignid_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.track_mbid
    ADD CONSTRAINT track_mbid_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.track_meta
    ADD CONSTRAINT track_meta_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.track
    ADD CONSTRAINT track_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.track_puid
    ADD CONSTRAINT track_puid_pkey PRIMARY KEY (id);



CREATE INDEX fingerprint_idx_length ON public.fingerprint USING btree (length);



CREATE INDEX fingerprint_idx_track_id ON public.fingerprint USING btree (track_id);



CREATE INDEX foreignid_idx_vendor ON public.foreignid USING btree (vendor_id);



CREATE UNIQUE INDEX foreignid_idx_vendor_name ON public.foreignid USING btree (vendor_id, name);



CREATE UNIQUE INDEX foreignid_vendor_idx_name ON public.foreignid_vendor USING btree (name);



CREATE INDEX track_foreignid_idx_foreignid_id ON public.track_foreignid USING btree (foreignid_id);



CREATE UNIQUE INDEX track_foreignid_idx_track_id_foreignid ON public.track_foreignid USING btree (track_id, foreignid_id);



CREATE UNIQUE INDEX track_foreignid_idx_uniq ON public.track_foreignid USING btree (track_id, foreignid_id);



CREATE INDEX track_idx_gid ON public.track USING btree (gid);



CREATE INDEX track_idx_new_id ON public.track USING btree (new_id) WHERE (new_id IS NOT NULL);



CREATE INDEX track_mbid_idx_mbid ON public.track_mbid USING btree (mbid);



CREATE UNIQUE INDEX track_mbid_idx_track_id_mbid ON public.track_mbid USING btree (track_id, mbid);



CREATE UNIQUE INDEX track_mbid_idx_uniq ON public.track_mbid USING btree (track_id, mbid);



CREATE INDEX track_meta_idx_meta_id ON public.track_meta USING btree (meta_id);



CREATE UNIQUE INDEX track_meta_idx_track_id_meta ON public.track_meta USING btree (track_id, meta_id);



CREATE UNIQUE INDEX track_meta_idx_uniq ON public.track_meta USING btree (track_id, meta_id);



CREATE INDEX track_puid_idx_puid ON public.track_puid USING btree (puid);



CREATE UNIQUE INDEX track_puid_idx_track_id_puid ON public.track_puid USING btree (track_id, puid);



CREATE UNIQUE INDEX track_puid_idx_uniq ON public.track_puid USING btree (track_id, puid);

































































































































ALTER TABLE ONLY public.fingerprint
    ADD CONSTRAINT fingerprint_fk_track_id FOREIGN KEY (track_id) REFERENCES public.track(id);



ALTER TABLE ONLY public.foreignid
    ADD CONSTRAINT foreignid_fk_vendor_id FOREIGN KEY (vendor_id) REFERENCES public.foreignid_vendor(id);



ALTER TABLE ONLY public.track
    ADD CONSTRAINT track_fk_new_id FOREIGN KEY (new_id) REFERENCES public.track(id);



ALTER TABLE ONLY public.track_foreignid
    ADD CONSTRAINT track_foreignid_fk_foreignid_id FOREIGN KEY (foreignid_id) REFERENCES public.foreignid(id);



ALTER TABLE ONLY public.track_foreignid
    ADD CONSTRAINT track_foreignid_fk_track_id FOREIGN KEY (track_id) REFERENCES public.track(id);



ALTER TABLE ONLY public.track_mbid
    ADD CONSTRAINT track_mbid_fk_track_id FOREIGN KEY (track_id) REFERENCES public.track(id);



ALTER TABLE ONLY public.track_meta
    ADD CONSTRAINT track_meta_fk_meta_id FOREIGN KEY (meta_id) REFERENCES public.meta(id);



ALTER TABLE ONLY public.track_meta
    ADD CONSTRAINT track_meta_fk_track_id FOREIGN KEY (track_id) REFERENCES public.track(id);



ALTER TABLE ONLY public.track_puid
    ADD CONSTRAINT track_puid_fk_track_id FOREIGN KEY (track_id) REFERENCES public.track(id);



