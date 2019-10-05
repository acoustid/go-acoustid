

SELECT pg_catalog.set_config('search_path', '', false);




CREATE TABLE account (
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



CREATE TABLE account_google (
    google_user_id character varying NOT NULL,
    account_id integer NOT NULL
);



CREATE SEQUENCE account_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE account_id_seq OWNED BY account.id;



CREATE TABLE account_openid (
    openid character varying NOT NULL,
    account_id integer NOT NULL
);



CREATE TABLE application (
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



CREATE SEQUENCE application_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE application_id_seq OWNED BY application.id;



CREATE TABLE format (
    id integer NOT NULL,
    name character varying NOT NULL
);



CREATE SEQUENCE format_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE format_id_seq OWNED BY format.id;



CREATE TABLE source (
    id integer NOT NULL,
    application_id integer NOT NULL,
    account_id integer NOT NULL,
    version character varying
);



CREATE SEQUENCE source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE source_id_seq OWNED BY source.id;



CREATE TABLE stats (
    id integer NOT NULL,
    name character varying NOT NULL,
    date date DEFAULT ('now'::text)::date NOT NULL,
    value integer NOT NULL
);



CREATE SEQUENCE stats_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE stats_id_seq OWNED BY stats.id;



CREATE TABLE stats_lookups (
    id integer NOT NULL,
    date date NOT NULL,
    hour integer NOT NULL,
    application_id integer NOT NULL,
    count_nohits integer DEFAULT 0 NOT NULL,
    count_hits integer DEFAULT 0 NOT NULL
);



CREATE SEQUENCE stats_lookups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE stats_lookups_id_seq OWNED BY stats_lookups.id;



CREATE TABLE stats_user_agents (
    id integer NOT NULL,
    date date NOT NULL,
    application_id integer NOT NULL,
    user_agent character varying NOT NULL,
    ip character varying NOT NULL,
    count integer DEFAULT 0 NOT NULL
);



CREATE SEQUENCE stats_user_agents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE stats_user_agents_id_seq OWNED BY stats_user_agents.id;



ALTER TABLE ONLY account ALTER COLUMN id SET DEFAULT nextval('account_id_seq'::regclass);



ALTER TABLE ONLY application ALTER COLUMN id SET DEFAULT nextval('application_id_seq'::regclass);



ALTER TABLE ONLY format ALTER COLUMN id SET DEFAULT nextval('format_id_seq'::regclass);



ALTER TABLE ONLY source ALTER COLUMN id SET DEFAULT nextval('source_id_seq'::regclass);



ALTER TABLE ONLY stats ALTER COLUMN id SET DEFAULT nextval('stats_id_seq'::regclass);



ALTER TABLE ONLY stats_lookups ALTER COLUMN id SET DEFAULT nextval('stats_lookups_id_seq'::regclass);



ALTER TABLE ONLY stats_user_agents ALTER COLUMN id SET DEFAULT nextval('stats_user_agents_id_seq'::regclass);



ALTER TABLE ONLY account_google
    ADD CONSTRAINT account_google_pkey PRIMARY KEY (google_user_id);



ALTER TABLE ONLY account_openid
    ADD CONSTRAINT account_openid_pkey PRIMARY KEY (openid);



ALTER TABLE ONLY account
    ADD CONSTRAINT account_pkey PRIMARY KEY (id);



ALTER TABLE ONLY application
    ADD CONSTRAINT application_pkey PRIMARY KEY (id);



ALTER TABLE ONLY format
    ADD CONSTRAINT format_pkey PRIMARY KEY (id);



ALTER TABLE ONLY source
    ADD CONSTRAINT source_pkey PRIMARY KEY (id);



ALTER TABLE ONLY stats_lookups
    ADD CONSTRAINT stats_lookups_pkey PRIMARY KEY (id);



ALTER TABLE ONLY stats
    ADD CONSTRAINT stats_pkey PRIMARY KEY (id);



ALTER TABLE ONLY stats_user_agents
    ADD CONSTRAINT stats_user_agents_pkey PRIMARY KEY (id);



CREATE INDEX account_google_idx_account_id ON account_google USING btree (account_id);



CREATE UNIQUE INDEX account_idx_apikey ON account USING btree (apikey);



CREATE UNIQUE INDEX account_idx_mbuser ON account USING btree (mbuser);



CREATE INDEX account_openid_idx_account_id ON account_openid USING btree (account_id);



CREATE UNIQUE INDEX format_idx_name ON format USING btree (name);



CREATE UNIQUE INDEX source_idx_uniq ON source USING btree (application_id, account_id, version);



CREATE INDEX stats_idx_date ON stats USING btree (date);



CREATE INDEX stats_idx_name_date ON stats USING btree (name, date);



CREATE INDEX stats_lookups_idx_date ON stats_lookups USING btree (date);



CREATE INDEX stats_user_agents_idx_date ON stats_user_agents USING btree (date);

































































































































ALTER TABLE ONLY account
    ADD CONSTRAINT account_fk_application_id FOREIGN KEY (application_id) REFERENCES application(id);



ALTER TABLE ONLY account_google
    ADD CONSTRAINT account_google_fk_account_id FOREIGN KEY (account_id) REFERENCES account(id);



ALTER TABLE ONLY account_openid
    ADD CONSTRAINT account_openid_fk_account_id FOREIGN KEY (account_id) REFERENCES account(id);



ALTER TABLE ONLY application
    ADD CONSTRAINT application_fk_account_id FOREIGN KEY (account_id) REFERENCES account(id);



ALTER TABLE ONLY stats_lookups
    ADD CONSTRAINT stats_lookups_fk_application_id FOREIGN KEY (application_id) REFERENCES application(id);



ALTER TABLE ONLY stats_user_agents
    ADD CONSTRAINT stats_user_agents_fk_application_id FOREIGN KEY (application_id) REFERENCES application(id);



