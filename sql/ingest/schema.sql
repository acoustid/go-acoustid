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

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: fingerprint_source; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.fingerprint_source (
    id integer NOT NULL,
    fingerprint_id integer NOT NULL,
    submission_id integer NOT NULL,
    source_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.fingerprint_source OWNER TO acoustid;

--
-- Name: fingerprint_source_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.fingerprint_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fingerprint_source_id_seq OWNER TO acoustid;

--
-- Name: fingerprint_source_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.fingerprint_source_id_seq OWNED BY public.fingerprint_source.id;


--
-- Name: submission; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.submission (
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


ALTER TABLE public.submission OWNER TO acoustid;

--
-- Name: submission_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.submission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.submission_id_seq OWNER TO acoustid;

--
-- Name: submission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.submission_id_seq OWNED BY public.submission.id;


--
-- Name: track_foreignid_source; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.track_foreignid_source (
    id integer NOT NULL,
    track_foreignid_id integer NOT NULL,
    submission_id integer NOT NULL,
    source_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.track_foreignid_source OWNER TO acoustid;

--
-- Name: track_foreignid_source_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.track_foreignid_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.track_foreignid_source_id_seq OWNER TO acoustid;

--
-- Name: track_foreignid_source_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.track_foreignid_source_id_seq OWNED BY public.track_foreignid_source.id;


--
-- Name: track_mbid_change; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.track_mbid_change (
    id integer NOT NULL,
    track_mbid_id integer NOT NULL,
    account_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    disabled boolean NOT NULL,
    note text
);


ALTER TABLE public.track_mbid_change OWNER TO acoustid;

--
-- Name: track_mbid_change_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.track_mbid_change_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.track_mbid_change_id_seq OWNER TO acoustid;

--
-- Name: track_mbid_change_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.track_mbid_change_id_seq OWNED BY public.track_mbid_change.id;


--
-- Name: track_mbid_source; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.track_mbid_source (
    id integer NOT NULL,
    track_mbid_id integer NOT NULL,
    submission_id integer,
    source_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.track_mbid_source OWNER TO acoustid;

--
-- Name: track_mbid_source_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.track_mbid_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.track_mbid_source_id_seq OWNER TO acoustid;

--
-- Name: track_mbid_source_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.track_mbid_source_id_seq OWNED BY public.track_mbid_source.id;


--
-- Name: track_meta_source; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.track_meta_source (
    id integer NOT NULL,
    track_meta_id integer NOT NULL,
    submission_id integer NOT NULL,
    source_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.track_meta_source OWNER TO acoustid;

--
-- Name: track_meta_source_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.track_meta_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.track_meta_source_id_seq OWNER TO acoustid;

--
-- Name: track_meta_source_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.track_meta_source_id_seq OWNED BY public.track_meta_source.id;


--
-- Name: track_puid_source; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.track_puid_source (
    id integer NOT NULL,
    track_puid_id integer NOT NULL,
    submission_id integer NOT NULL,
    source_id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.track_puid_source OWNER TO acoustid;

--
-- Name: track_puid_source_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.track_puid_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.track_puid_source_id_seq OWNER TO acoustid;

--
-- Name: track_puid_source_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.track_puid_source_id_seq OWNED BY public.track_puid_source.id;


--
-- Name: fingerprint_source id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.fingerprint_source ALTER COLUMN id SET DEFAULT nextval('public.fingerprint_source_id_seq'::regclass);


--
-- Name: submission id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.submission ALTER COLUMN id SET DEFAULT nextval('public.submission_id_seq'::regclass);


--
-- Name: track_foreignid_source id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_foreignid_source ALTER COLUMN id SET DEFAULT nextval('public.track_foreignid_source_id_seq'::regclass);


--
-- Name: track_mbid_change id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_mbid_change ALTER COLUMN id SET DEFAULT nextval('public.track_mbid_change_id_seq'::regclass);


--
-- Name: track_mbid_source id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_mbid_source ALTER COLUMN id SET DEFAULT nextval('public.track_mbid_source_id_seq'::regclass);


--
-- Name: track_meta_source id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_meta_source ALTER COLUMN id SET DEFAULT nextval('public.track_meta_source_id_seq'::regclass);


--
-- Name: track_puid_source id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_puid_source ALTER COLUMN id SET DEFAULT nextval('public.track_puid_source_id_seq'::regclass);


--
-- Name: fingerprint_source fingerprint_source_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.fingerprint_source
    ADD CONSTRAINT fingerprint_source_pkey PRIMARY KEY (id);


--
-- Name: submission submission_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.submission
    ADD CONSTRAINT submission_pkey PRIMARY KEY (id);


--
-- Name: track_foreignid_source track_foreignid_source_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_foreignid_source
    ADD CONSTRAINT track_foreignid_source_pkey PRIMARY KEY (id);


--
-- Name: track_mbid_change track_mbid_change_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_mbid_change
    ADD CONSTRAINT track_mbid_change_pkey PRIMARY KEY (id);


--
-- Name: track_mbid_source track_mbid_source_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_mbid_source
    ADD CONSTRAINT track_mbid_source_pkey PRIMARY KEY (id);


--
-- Name: track_meta_source track_meta_source_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_meta_source
    ADD CONSTRAINT track_meta_source_pkey PRIMARY KEY (id);


--
-- Name: track_puid_source track_puid_source_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.track_puid_source
    ADD CONSTRAINT track_puid_source_pkey PRIMARY KEY (id);


--
-- Name: fingerprint_source_idx_submission_id; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX fingerprint_source_idx_submission_id ON public.fingerprint_source USING btree (submission_id);


--
-- Name: submission_idx_handled; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX submission_idx_handled ON public.submission USING btree (id) WHERE (handled = false);


--
-- Name: track_mbid_change_idx_track_mbid_id; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX track_mbid_change_idx_track_mbid_id ON public.track_mbid_change USING btree (track_mbid_id);


--
-- Name: track_mbid_source_idx_track_mbid_id; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX track_mbid_source_idx_track_mbid_id ON public.track_mbid_source USING btree (track_mbid_id);


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
-- PostgreSQL database dump complete
--

