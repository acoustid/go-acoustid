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
-- Name: account; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.account (
    id integer NOT NULL,
    name character varying NOT NULL,
    apikey character varying NOT NULL,
    mbuser character varying,
    anonymous boolean DEFAULT false,
    created timestamp with time zone DEFAULT now(),
    lastlogin timestamp with time zone,
    submission_count integer DEFAULT 0 NOT NULL,
    application_id integer,
    application_version character varying,
    created_from inet,
    is_admin boolean DEFAULT false NOT NULL
);


ALTER TABLE public.account OWNER TO acoustid;

--
-- Name: account_google; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.account_google (
    google_user_id character varying NOT NULL,
    account_id integer NOT NULL
);


ALTER TABLE public.account_google OWNER TO acoustid;

--
-- Name: account_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.account_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.account_id_seq OWNER TO acoustid;

--
-- Name: account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.account_id_seq OWNED BY public.account.id;


--
-- Name: account_openid; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.account_openid (
    openid character varying NOT NULL,
    account_id integer NOT NULL
);


ALTER TABLE public.account_openid OWNER TO acoustid;

--
-- Name: application; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.application (
    id integer NOT NULL,
    name character varying NOT NULL,
    version character varying NOT NULL,
    apikey character varying NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    active boolean DEFAULT true,
    account_id integer NOT NULL,
    email character varying,
    website character varying
);


ALTER TABLE public.application OWNER TO acoustid;

--
-- Name: application_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.application_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.application_id_seq OWNER TO acoustid;

--
-- Name: application_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.application_id_seq OWNED BY public.application.id;


--
-- Name: format; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.format (
    id integer NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE public.format OWNER TO acoustid;

--
-- Name: format_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.format_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.format_id_seq OWNER TO acoustid;

--
-- Name: format_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.format_id_seq OWNED BY public.format.id;


--
-- Name: source; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.source (
    id integer NOT NULL,
    application_id integer NOT NULL,
    account_id integer NOT NULL,
    version character varying
);


ALTER TABLE public.source OWNER TO acoustid;

--
-- Name: source_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.source_id_seq OWNER TO acoustid;

--
-- Name: source_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.source_id_seq OWNED BY public.source.id;


--
-- Name: stats; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.stats (
    id integer NOT NULL,
    name character varying NOT NULL,
    date date DEFAULT ('now'::text)::date NOT NULL,
    value integer NOT NULL
);


ALTER TABLE public.stats OWNER TO acoustid;

--
-- Name: stats_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.stats_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stats_id_seq OWNER TO acoustid;

--
-- Name: stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.stats_id_seq OWNED BY public.stats.id;


--
-- Name: stats_lookups; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.stats_lookups (
    id integer NOT NULL,
    date date NOT NULL,
    hour integer NOT NULL,
    application_id integer NOT NULL,
    count_nohits integer DEFAULT 0 NOT NULL,
    count_hits integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.stats_lookups OWNER TO acoustid;

--
-- Name: stats_lookups_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.stats_lookups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stats_lookups_id_seq OWNER TO acoustid;

--
-- Name: stats_lookups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.stats_lookups_id_seq OWNED BY public.stats_lookups.id;


--
-- Name: stats_user_agents; Type: TABLE; Schema: public; Owner: acoustid
--

CREATE TABLE public.stats_user_agents (
    id integer NOT NULL,
    date date NOT NULL,
    application_id integer NOT NULL,
    user_agent character varying NOT NULL,
    ip character varying NOT NULL,
    count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.stats_user_agents OWNER TO acoustid;

--
-- Name: stats_user_agents_id_seq; Type: SEQUENCE; Schema: public; Owner: acoustid
--

CREATE SEQUENCE public.stats_user_agents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stats_user_agents_id_seq OWNER TO acoustid;

--
-- Name: stats_user_agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: acoustid
--

ALTER SEQUENCE public.stats_user_agents_id_seq OWNED BY public.stats_user_agents.id;


--
-- Name: account id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.account ALTER COLUMN id SET DEFAULT nextval('public.account_id_seq'::regclass);


--
-- Name: application id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.application ALTER COLUMN id SET DEFAULT nextval('public.application_id_seq'::regclass);


--
-- Name: format id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.format ALTER COLUMN id SET DEFAULT nextval('public.format_id_seq'::regclass);


--
-- Name: source id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.source ALTER COLUMN id SET DEFAULT nextval('public.source_id_seq'::regclass);


--
-- Name: stats id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.stats ALTER COLUMN id SET DEFAULT nextval('public.stats_id_seq'::regclass);


--
-- Name: stats_lookups id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.stats_lookups ALTER COLUMN id SET DEFAULT nextval('public.stats_lookups_id_seq'::regclass);


--
-- Name: stats_user_agents id; Type: DEFAULT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.stats_user_agents ALTER COLUMN id SET DEFAULT nextval('public.stats_user_agents_id_seq'::regclass);


--
-- Name: account_google account_google_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.account_google
    ADD CONSTRAINT account_google_pkey PRIMARY KEY (google_user_id);


--
-- Name: account_openid account_openid_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.account_openid
    ADD CONSTRAINT account_openid_pkey PRIMARY KEY (openid);


--
-- Name: account account_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_pkey PRIMARY KEY (id);


--
-- Name: application application_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.application
    ADD CONSTRAINT application_pkey PRIMARY KEY (id);


--
-- Name: format format_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.format
    ADD CONSTRAINT format_pkey PRIMARY KEY (id);


--
-- Name: source source_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.source
    ADD CONSTRAINT source_pkey PRIMARY KEY (id);


--
-- Name: stats_lookups stats_lookups_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.stats_lookups
    ADD CONSTRAINT stats_lookups_pkey PRIMARY KEY (id);


--
-- Name: stats stats_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.stats
    ADD CONSTRAINT stats_pkey PRIMARY KEY (id);


--
-- Name: stats_user_agents stats_user_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.stats_user_agents
    ADD CONSTRAINT stats_user_agents_pkey PRIMARY KEY (id);


--
-- Name: account_google_idx_account_id; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX account_google_idx_account_id ON public.account_google USING btree (account_id);


--
-- Name: account_idx_apikey; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX account_idx_apikey ON public.account USING btree (apikey);


--
-- Name: account_idx_mbuser; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX account_idx_mbuser ON public.account USING btree (mbuser);


--
-- Name: account_openid_idx_account_id; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX account_openid_idx_account_id ON public.account_openid USING btree (account_id);


--
-- Name: format_idx_name; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX format_idx_name ON public.format USING btree (name);


--
-- Name: source_idx_uniq; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE UNIQUE INDEX source_idx_uniq ON public.source USING btree (application_id, account_id, version);


--
-- Name: stats_idx_date; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX stats_idx_date ON public.stats USING btree (date);


--
-- Name: stats_idx_name_date; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX stats_idx_name_date ON public.stats USING btree (name, date);


--
-- Name: stats_lookups_idx_date; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX stats_lookups_idx_date ON public.stats_lookups USING btree (date);


--
-- Name: stats_user_agents_idx_date; Type: INDEX; Schema: public; Owner: acoustid
--

CREATE INDEX stats_user_agents_idx_date ON public.stats_user_agents USING btree (date);


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
-- Name: account account_fk_application_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_fk_application_id FOREIGN KEY (application_id) REFERENCES public.application(id);


--
-- Name: account_google account_google_fk_account_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.account_google
    ADD CONSTRAINT account_google_fk_account_id FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: account_openid account_openid_fk_account_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.account_openid
    ADD CONSTRAINT account_openid_fk_account_id FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: application application_fk_account_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.application
    ADD CONSTRAINT application_fk_account_id FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: stats_lookups stats_lookups_fk_application_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.stats_lookups
    ADD CONSTRAINT stats_lookups_fk_application_id FOREIGN KEY (application_id) REFERENCES public.application(id);


--
-- Name: stats_user_agents stats_user_agents_fk_application_id; Type: FK CONSTRAINT; Schema: public; Owner: acoustid
--

ALTER TABLE ONLY public.stats_user_agents
    ADD CONSTRAINT stats_user_agents_fk_application_id FOREIGN KEY (application_id) REFERENCES public.application(id);


--
-- PostgreSQL database dump complete
--

