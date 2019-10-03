--
-- PostgreSQL database dump
--

-- Dumped from database version 11.5 (Debian 11.5-1.pgdg90+1)
-- Dumped by pg_dump version 11.5 (Debian 11.5-1.pgdg90+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: acoustid; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS acoustid WITH SCHEMA public;


--
-- Name: EXTENSION acoustid; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION acoustid IS 'AcoustID utility functions';


--
-- Name: intarray; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS intarray WITH SCHEMA public;


--
-- Name: EXTENSION intarray; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION intarray IS 'functions, operators, and index support for 1-D arrays of integers';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: fingerprint; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.fingerprint (
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


ALTER TABLE public.fingerprint OWNER TO acoustid;

--
-- Name: fingerprint_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.fingerprint_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fingerprint_id_seq OWNER TO acoustid;

--
-- Name: fingerprint_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.fingerprint_id_seq OWNED BY public.fingerprint.id;


--
-- Name: foreignid; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.foreignid (
    id integer NOT NULL,
    vendor_id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.foreignid OWNER TO acoustid;

--
-- Name: foreignid_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.foreignid_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.foreignid_id_seq OWNER TO acoustid;

--
-- Name: foreignid_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.foreignid_id_seq OWNED BY public.foreignid.id;


--
-- Name: foreignid_vendor; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.foreignid_vendor (
    id integer NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE public.foreignid_vendor OWNER TO acoustid;

--
-- Name: foreignid_vendor_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.foreignid_vendor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.foreignid_vendor_id_seq OWNER TO acoustid;

--
-- Name: foreignid_vendor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.foreignid_vendor_id_seq OWNED BY public.foreignid_vendor.id;


--
-- Name: meta; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.meta (
    id integer NOT NULL,
    track character varying,
    artist character varying,
    album character varying,
    album_artist character varying,
    track_no integer,
    disc_no integer,
    year integer
);


ALTER TABLE public.meta OWNER TO acoustid;

--
-- Name: meta_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.meta_id_seq OWNER TO acoustid;

--
-- Name: meta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.meta_id_seq OWNED BY public.meta.id;


--
-- Name: track; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.track (
    id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    gid uuid NOT NULL,
    new_id integer
);


ALTER TABLE public.track OWNER TO acoustid;

--
-- Name: track_foreignid; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.track_foreignid (
    id integer NOT NULL,
    track_id integer NOT NULL,
    foreignid_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL
);


ALTER TABLE public.track_foreignid OWNER TO acoustid;

--
-- Name: track_foreignid_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.track_foreignid_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.track_foreignid_id_seq OWNER TO acoustid;

--
-- Name: track_foreignid_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.track_foreignid_id_seq OWNED BY public.track_foreignid.id;


--
-- Name: track_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.track_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.track_id_seq OWNER TO acoustid;

--
-- Name: track_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.track_id_seq OWNED BY public.track.id;


--
-- Name: track_mbid; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.track_mbid (
    id integer NOT NULL,
    track_id integer NOT NULL,
    mbid uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL,
    disabled boolean DEFAULT false NOT NULL
);


ALTER TABLE public.track_mbid OWNER TO acoustid;

--
-- Name: track_mbid_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.track_mbid_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.track_mbid_id_seq OWNER TO acoustid;

--
-- Name: track_mbid_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.track_mbid_id_seq OWNED BY public.track_mbid.id;


--
-- Name: track_meta; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.track_meta (
    id integer NOT NULL,
    track_id integer NOT NULL,
    meta_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL
);


ALTER TABLE public.track_meta OWNER TO acoustid;

--
-- Name: track_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.track_meta_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.track_meta_id_seq OWNER TO acoustid;

--
-- Name: track_meta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.track_meta_id_seq OWNED BY public.track_meta.id;


--
-- Name: track_puid; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.track_puid (
    id integer NOT NULL,
    track_id integer NOT NULL,
    puid uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    submission_count integer NOT NULL
);


ALTER TABLE public.track_puid OWNER TO acoustid;

--
-- Name: track_puid_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.track_puid_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.track_puid_id_seq OWNER TO acoustid;

--
-- Name: track_puid_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.track_puid_id_seq OWNED BY public.track_puid.id;


--
-- Name: fingerprint id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.fingerprint ALTER COLUMN id SET DEFAULT nextval('public.fingerprint_id_seq'::regclass);


--
-- Name: foreignid id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.foreignid ALTER COLUMN id SET DEFAULT nextval('public.foreignid_id_seq'::regclass);


--
-- Name: foreignid_vendor id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.foreignid_vendor ALTER COLUMN id SET DEFAULT nextval('public.foreignid_vendor_id_seq'::regclass);


--
-- Name: meta id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.meta ALTER COLUMN id SET DEFAULT nextval('public.meta_id_seq'::regclass);


--
-- Name: track id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track ALTER COLUMN id SET DEFAULT nextval('public.track_id_seq'::regclass);


--
-- Name: track_foreignid id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_foreignid ALTER COLUMN id SET DEFAULT nextval('public.track_foreignid_id_seq'::regclass);


--
-- Name: track_mbid id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_mbid ALTER COLUMN id SET DEFAULT nextval('public.track_mbid_id_seq'::regclass);


--
-- Name: track_meta id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_meta ALTER COLUMN id SET DEFAULT nextval('public.track_meta_id_seq'::regclass);


--
-- Name: track_puid id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_puid ALTER COLUMN id SET DEFAULT nextval('public.track_puid_id_seq'::regclass);


--
-- Name: fingerprint fingerprint_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.fingerprint
    ADD CONSTRAINT fingerprint_pkey PRIMARY KEY (id);


--
-- Name: foreignid foreignid_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.foreignid
    ADD CONSTRAINT foreignid_pkey PRIMARY KEY (id);


--
-- Name: foreignid_vendor foreignid_vendor_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.foreignid_vendor
    ADD CONSTRAINT foreignid_vendor_pkey PRIMARY KEY (id);


--
-- Name: meta meta_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.meta
    ADD CONSTRAINT meta_pkey PRIMARY KEY (id);


--
-- Name: track_foreignid track_foreignid_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_foreignid
    ADD CONSTRAINT track_foreignid_pkey PRIMARY KEY (id);


--
-- Name: track_mbid track_mbid_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_mbid
    ADD CONSTRAINT track_mbid_pkey PRIMARY KEY (id);


--
-- Name: track_meta track_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_meta
    ADD CONSTRAINT track_meta_pkey PRIMARY KEY (id);


--
-- Name: track track_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track
    ADD CONSTRAINT track_pkey PRIMARY KEY (id);


--
-- Name: track_puid track_puid_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_puid
    ADD CONSTRAINT track_puid_pkey PRIMARY KEY (id);


--
-- Name: fingerprint_idx_length; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX fingerprint_idx_length ON public.fingerprint USING btree (length);


--
-- Name: fingerprint_idx_track_id; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX fingerprint_idx_track_id ON public.fingerprint USING btree (track_id);


--
-- Name: foreignid_idx_vendor; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX foreignid_idx_vendor ON public.foreignid USING btree (vendor_id);


--
-- Name: foreignid_idx_vendor_name; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX foreignid_idx_vendor_name ON public.foreignid USING btree (vendor_id, name);


--
-- Name: foreignid_vendor_idx_name; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX foreignid_vendor_idx_name ON public.foreignid_vendor USING btree (name);


--
-- Name: track_foreignid_idx_foreignid_id; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX track_foreignid_idx_foreignid_id ON public.track_foreignid USING btree (foreignid_id);


--
-- Name: track_foreignid_idx_track_id_foreignid; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX track_foreignid_idx_track_id_foreignid ON public.track_foreignid USING btree (track_id, foreignid_id);


--
-- Name: track_foreignid_idx_uniq; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX track_foreignid_idx_uniq ON public.track_foreignid USING btree (track_id, foreignid_id);


--
-- Name: track_idx_gid; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX track_idx_gid ON public.track USING btree (gid);


--
-- Name: track_idx_new_id; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX track_idx_new_id ON public.track USING btree (new_id) WHERE (new_id IS NOT NULL);


--
-- Name: track_mbid_idx_mbid; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX track_mbid_idx_mbid ON public.track_mbid USING btree (mbid);


--
-- Name: track_mbid_idx_track_id_mbid; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX track_mbid_idx_track_id_mbid ON public.track_mbid USING btree (track_id, mbid);


--
-- Name: track_mbid_idx_uniq; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX track_mbid_idx_uniq ON public.track_mbid USING btree (track_id, mbid);


--
-- Name: track_meta_idx_meta_id; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX track_meta_idx_meta_id ON public.track_meta USING btree (meta_id);


--
-- Name: track_meta_idx_track_id_meta; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX track_meta_idx_track_id_meta ON public.track_meta USING btree (track_id, meta_id);


--
-- Name: track_meta_idx_uniq; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX track_meta_idx_uniq ON public.track_meta USING btree (track_id, meta_id);


--
-- Name: track_puid_idx_puid; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX track_puid_idx_puid ON public.track_puid USING btree (puid);


--
-- Name: track_puid_idx_track_id_puid; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX track_puid_idx_track_id_puid ON public.track_puid USING btree (track_id, puid);


--
-- Name: track_puid_idx_uniq; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX track_puid_idx_uniq ON public.track_puid USING btree (track_id, puid);


--
--



--
--



--
--



--
--



--
--



--
--



--
--



--
--



--
--



--
--




--
--




--
--




--
--




--
--




--
--




--
--




--
--




--
--




--
--



--
--



--
--



--
--



--
--



--
--



--
--



--
--



--
--



--
--




--
--




--
--




--
--




--
--




--
--




--
--




--
--




--
--




--
-- Name: fingerprint fingerprint_fk_track_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.fingerprint
    ADD CONSTRAINT fingerprint_fk_track_id FOREIGN KEY (track_id) REFERENCES public.track(id);


--
-- Name: foreignid foreignid_fk_vendor_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.foreignid
    ADD CONSTRAINT foreignid_fk_vendor_id FOREIGN KEY (vendor_id) REFERENCES public.foreignid_vendor(id);


--
-- Name: track track_fk_new_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track
    ADD CONSTRAINT track_fk_new_id FOREIGN KEY (new_id) REFERENCES public.track(id);


--
-- Name: track_foreignid track_foreignid_fk_foreignid_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_foreignid
    ADD CONSTRAINT track_foreignid_fk_foreignid_id FOREIGN KEY (foreignid_id) REFERENCES public.foreignid(id);


--
-- Name: track_foreignid track_foreignid_fk_track_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_foreignid
    ADD CONSTRAINT track_foreignid_fk_track_id FOREIGN KEY (track_id) REFERENCES public.track(id);


--
-- Name: track_mbid track_mbid_fk_track_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_mbid
    ADD CONSTRAINT track_mbid_fk_track_id FOREIGN KEY (track_id) REFERENCES public.track(id);


--
-- Name: track_meta track_meta_fk_meta_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_meta
    ADD CONSTRAINT track_meta_fk_meta_id FOREIGN KEY (meta_id) REFERENCES public.meta(id);


--
-- Name: track_meta track_meta_fk_track_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_meta
    ADD CONSTRAINT track_meta_fk_track_id FOREIGN KEY (track_id) REFERENCES public.track(id);


--
-- Name: track_puid track_puid_fk_track_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_puid
    ADD CONSTRAINT track_puid_fk_track_id FOREIGN KEY (track_id) REFERENCES public.track(id);


--
-- PostgreSQL database dump complete
--

