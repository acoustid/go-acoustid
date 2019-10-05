

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


CREATE SCHEMA cover_art_archive;



CREATE SCHEMA documentation;



CREATE SCHEMA event_art_archive;



CREATE SCHEMA musicbrainz;



CREATE SCHEMA statistics;



CREATE SCHEMA wikidocs;



CREATE EXTENSION IF NOT EXISTS cube WITH SCHEMA public;






CREATE EXTENSION IF NOT EXISTS earthdistance WITH SCHEMA public;






CREATE TYPE musicbrainz.cover_art_presence AS ENUM (
    'absent',
    'present',
    'darkened'
);



CREATE TYPE musicbrainz.event_art_presence AS ENUM (
    'absent',
    'present',
    'darkened'
);



CREATE TYPE musicbrainz.fluency AS ENUM (
    'basic',
    'intermediate',
    'advanced',
    'native'
);



CREATE FUNCTION musicbrainz._median(anyarray) RETURNS anyelement
    LANGUAGE sql IMMUTABLE
    AS $_$
  WITH q AS (
      SELECT val
      FROM unnest($1) val
      WHERE VAL IS NOT NULL
      ORDER BY val
  )
  SELECT val
  FROM q
  LIMIT 1
  -- Subtracting (n + 1) % 2 creates a left bias
  OFFSET greatest(0, floor((select count(*) FROM q) / 2.0) - ((select count(*) + 1 FROM q) % 2));
$_$;



CREATE FUNCTION musicbrainz.a_del_alternative_medium_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM dec_ref_count('alternative_track', OLD.alternative_track, 1);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_del_alternative_release_or_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM dec_nullable_artist_credit(OLD.artist_credit);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_del_instrument() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM link_attribute_type WHERE gid = OLD.gid;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'no link_attribute_type found for instrument %', NEW.gid;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.a_del_recording() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM dec_ref_count('artist_credit', OLD.artist_credit, 1);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_del_release() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- decrement ref_count of the name
    PERFORM dec_ref_count('artist_credit', OLD.artist_credit, 1);
    -- decrement release_count of the parent release group
    UPDATE release_group_meta SET release_count = release_count - 1 WHERE id = OLD.release_group;
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_del_release_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM set_release_group_first_release_date(release_group)
  FROM release
  WHERE release.id = OLD.release;
  RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_del_release_group() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM dec_ref_count('artist_credit', OLD.artist_credit, 1);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_del_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM dec_ref_count('artist_credit', OLD.artist_credit, 1);
    -- decrement track_count in the parent medium
    UPDATE medium SET track_count = track_count - 1 WHERE id = OLD.medium;
    PERFORM materialise_recording_length(OLD.recording);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_alternative_medium_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM inc_ref_count('alternative_track', NEW.alternative_track, 1);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_alternative_release_or_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM inc_nullable_artist_credit(NEW.artist_credit);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_artist() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- add a new entry to the artist_meta table
    INSERT INTO artist_meta (id) VALUES (NEW.id);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_edit_note() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO edit_note_recipient (recipient, edit_note) (
        SELECT edit.editor, NEW.id
          FROM edit
         WHERE edit.id = NEW.edit
           AND edit.editor != NEW.editor
    );
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_editor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- add a new entry to the editor_watch_preference table
    INSERT INTO editor_watch_preferences (editor) VALUES (NEW.id);

    -- by default watch for new official albums
    INSERT INTO editor_watch_release_group_type (editor, release_group_type)
        VALUES (NEW.id, 2);
    INSERT INTO editor_watch_release_status (editor, release_status)
        VALUES (NEW.id, 1);

    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- add a new entry to the event_meta table
    INSERT INTO event_meta (id) VALUES (NEW.id);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_instrument() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    WITH inserted_rows (id) AS (
        INSERT INTO link_attribute_type (parent, root, child_order, gid, name, description)
        VALUES (14, 14, 0, NEW.gid, NEW.name, NEW.description)
        RETURNING id
    ) INSERT INTO link_creditable_attribute_type (attribute_type) SELECT id FROM inserted_rows;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_label() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO label_meta (id) VALUES (NEW.id);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_recording() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM inc_ref_count('artist_credit', NEW.artist_credit, 1);
    INSERT INTO recording_meta (id) VALUES (NEW.id);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_release() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- increment ref_count of the name
    PERFORM inc_ref_count('artist_credit', NEW.artist_credit, 1);
    -- increment release_count of the parent release group
    UPDATE release_group_meta SET release_count = release_count + 1 WHERE id = NEW.release_group;
    -- add new release_meta
    INSERT INTO release_meta (id) VALUES (NEW.id);
    INSERT INTO release_coverart (id) VALUES (NEW.id);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_release_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM set_release_group_first_release_date(release_group)
  FROM release
  WHERE release.id = NEW.release;
  RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_release_group() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM inc_ref_count('artist_credit', NEW.artist_credit, 1);
    INSERT INTO release_group_meta (id) VALUES (NEW.id);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM inc_ref_count('artist_credit', NEW.artist_credit, 1);
    -- increment track_count in the parent medium
    UPDATE medium SET track_count = track_count + 1 WHERE id = NEW.medium;
    PERFORM materialise_recording_length(NEW.recording);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_ins_work() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO work_meta (id) VALUES (NEW.id);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_upd_alternative_medium_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.alternative_track IS DISTINCT FROM OLD.alternative_track THEN
        PERFORM inc_ref_count('alternative_track', NEW.alternative_track, 1);
        PERFORM dec_ref_count('alternative_track', OLD.alternative_track, 1);
    END IF;
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_upd_alternative_release_or_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.artist_credit IS DISTINCT FROM OLD.artist_credit THEN
        PERFORM inc_nullable_artist_credit(NEW.artist_credit);
        PERFORM dec_nullable_artist_credit(OLD.artist_credit);
    END IF;
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_upd_edit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.status != OLD.status THEN
       UPDATE edit_artist SET status = NEW.status WHERE edit = NEW.id;
       UPDATE edit_label  SET status = NEW.status WHERE edit = NEW.id;
    END IF;
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_upd_instrument() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE link_attribute_type SET name = NEW.name, description = NEW.description WHERE gid = NEW.gid;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'no link_attribute_type found for instrument %', NEW.gid;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.a_upd_recording() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.artist_credit != OLD.artist_credit THEN
        PERFORM dec_ref_count('artist_credit', OLD.artist_credit, 1);
        PERFORM inc_ref_count('artist_credit', NEW.artist_credit, 1);
    END IF;
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_upd_release() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.artist_credit != OLD.artist_credit THEN
        PERFORM dec_ref_count('artist_credit', OLD.artist_credit, 1);
        PERFORM inc_ref_count('artist_credit', NEW.artist_credit, 1);
    END IF;
    IF NEW.release_group != OLD.release_group THEN
        -- release group is changed, decrement release_count in the original RG, increment in the new one
        UPDATE release_group_meta SET release_count = release_count - 1 WHERE id = OLD.release_group;
        UPDATE release_group_meta SET release_count = release_count + 1 WHERE id = NEW.release_group;
        PERFORM set_release_group_first_release_date(OLD.release_group);
        PERFORM set_release_group_first_release_date(NEW.release_group);
    END IF;
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_upd_release_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM set_release_group_first_release_date(release_group)
  FROM release
  WHERE release.id IN (NEW.release, OLD.release);
  RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_upd_release_group() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.artist_credit != OLD.artist_credit THEN
        PERFORM dec_ref_count('artist_credit', OLD.artist_credit, 1);
        PERFORM inc_ref_count('artist_credit', NEW.artist_credit, 1);
    END IF;
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.a_upd_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.artist_credit != OLD.artist_credit THEN
        PERFORM dec_ref_count('artist_credit', OLD.artist_credit, 1);
        PERFORM inc_ref_count('artist_credit', NEW.artist_credit, 1);
    END IF;
    IF NEW.medium != OLD.medium THEN
        -- medium is changed, decrement track_count in the original medium, increment in the new one
        UPDATE medium SET track_count = track_count - 1 WHERE id = OLD.medium;
        UPDATE medium SET track_count = track_count + 1 WHERE id = NEW.medium;
    END IF;
    IF OLD.recording <> NEW.recording THEN
      PERFORM materialise_recording_length(OLD.recording);
    END IF;
    PERFORM materialise_recording_length(NEW.recording);
    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.b_ins_edit_materialize_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.status = (SELECT status FROM edit WHERE id = NEW.edit);
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.b_upd_last_updated_table() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.last_updated = NOW();
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.b_upd_recording() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.length IS DISTINCT FROM NEW.length
    AND EXISTS (SELECT TRUE FROM track WHERE recording = NEW.id)
    AND NEW.length IS DISTINCT FROM median_track_length(NEW.id)
  THEN
    NEW.length = median_track_length(NEW.id);
  END IF;

  NEW.last_updated = now();
  RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.check_editor_name() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT 1 FROM old_editor_name WHERE lower(name) = lower(NEW.name))
    THEN
        RAISE EXCEPTION 'Attempt to use a previously-used editor name.';
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.check_has_dates() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (NEW.begin_date_year IS NOT NULL OR
       NEW.begin_date_month IS NOT NULL OR
       NEW.begin_date_day IS NOT NULL OR
       NEW.end_date_year IS NOT NULL OR
       NEW.end_date_month IS NOT NULL OR
       NEW.end_date_day IS NOT NULL OR
       NEW.ended = TRUE)
       AND NOT (SELECT has_dates FROM link_type WHERE id = NEW.link_type)
  THEN
    RAISE EXCEPTION 'Attempt to add dates to a relationship type that does not support dates.';
  END IF;
  RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.controlled_for_whitespace(text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'musicbrainz', 'public'
    AS $_$
  SELECT NOT padded_by_whitespace($1) AND whitespace_collapsed($1);
$_$;



CREATE FUNCTION musicbrainz.create_bounding_cube(durations integer[], fuzzy integer) RETURNS public.cube
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    point    cube;
    str      VARCHAR;
    i        INTEGER;
    dest     INTEGER;
    count    INTEGER;
    dim      CONSTANT INTEGER = 6;
    selected INTEGER[];
    scalers  INTEGER[];
BEGIN

    count = array_upper(durations, 1);
    IF count < dim THEN
        FOR i IN 1..dim LOOP
            selected[i] = 0;
            scalers[i] = 0;
        END LOOP;
        FOR i IN 1..count LOOP
            selected[i] = durations[i];
            scalers[i] = 1;
        END LOOP;
    ELSE
        FOR i IN 1..dim LOOP
            selected[i] = 0;
            scalers[i] = 0;
        END LOOP;
        FOR i IN 1..count LOOP
            dest = (dim * (i-1) / count) + 1;
            selected[dest] = selected[dest] + durations[i];
            scalers[dest] = scalers[dest] + 1;
        END LOOP;
    END IF;

    str = '(';
    FOR i IN 1..dim LOOP
        IF i > 1 THEN
            str = str || ',';
        END IF;
        str = str || cast((selected[i] - (fuzzy * scalers[i])) as text);
    END LOOP;
    str = str || '),(';
    FOR i IN 1..dim LOOP
        IF i > 1 THEN
            str = str || ',';
        END IF;
        str = str || cast((selected[i] + (fuzzy * scalers[i])) as text);
    END LOOP;
    str = str || ')';

    RETURN str::cube;
END;
$$;



CREATE FUNCTION musicbrainz.create_cube_from_durations(durations integer[]) RETURNS public.cube
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    point    cube;
    str      VARCHAR;
    i        INTEGER;
    count    INTEGER;
    dest     INTEGER;
    dim      CONSTANT INTEGER = 6;
    selected INTEGER[];
BEGIN

    count = array_upper(durations, 1);
    FOR i IN 0..dim LOOP
        selected[i] = 0;
    END LOOP;

    IF count < dim THEN
        FOR i IN 1..count LOOP
            selected[i] = durations[i];
        END LOOP;
    ELSE
        FOR i IN 1..count LOOP
            dest = (dim * (i-1) / count) + 1;
            selected[dest] = selected[dest] + durations[i];
        END LOOP;
    END IF;

    str = '(';
    FOR i IN 1..dim LOOP
        IF i > 1 THEN
            str = str || ',';
        END IF;
        str = str || cast(selected[i] as text);
    END LOOP;
    str = str || ')';

    RETURN str::cube;
END;
$$;



CREATE FUNCTION musicbrainz.dec_nullable_artist_credit(row_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF row_id IS NOT NULL THEN
        PERFORM dec_ref_count('artist_credit', row_id, 1);
    END IF;
    RETURN;
END;
$$;



CREATE FUNCTION musicbrainz.dec_ref_count(tbl character varying, row_id integer, val integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    ref_count integer;
BEGIN
    -- decrement ref_count for the old name,
    -- or delete it if ref_count would drop to 0
    EXECUTE 'SELECT ref_count FROM ' || tbl || ' WHERE id = ' || row_id || ' FOR UPDATE' INTO ref_count;
    IF ref_count <= val THEN
        EXECUTE 'DELETE FROM ' || tbl || ' WHERE id = ' || row_id;
    ELSE
        EXECUTE 'UPDATE ' || tbl || ' SET ref_count = ref_count - ' || val || ' WHERE id = ' || row_id;
    END IF;
    RETURN;
END;
$$;



CREATE FUNCTION musicbrainz.del_collection_sub_on_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    UPDATE editor_subscribe_collection sub
     SET available = FALSE, last_seen_name = OLD.name
     FROM editor_collection coll
     WHERE sub.collection = OLD.id AND sub.collection = coll.id;

    RETURN OLD;
  END;
$$;



CREATE FUNCTION musicbrainz.del_collection_sub_on_private() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    IF NEW.public = FALSE AND OLD.public = TRUE THEN
      UPDATE editor_subscribe_collection sub
       SET available = FALSE, last_seen_name = OLD.name
       FROM editor_collection coll
       WHERE sub.collection = OLD.id AND sub.collection = coll.id
       AND sub.editor != coll.editor;
    END IF;

    RETURN NEW;
  END;
$$;



CREATE FUNCTION musicbrainz.delete_orphaned_recordings() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    PERFORM TRUE
    FROM recording outer_r
    WHERE id = OLD.recording
      AND edits_pending = 0
      AND NOT EXISTS (
        SELECT TRUE
        FROM edit JOIN edit_recording er ON edit.id = er.edit
        WHERE er.recording = outer_r.id
          AND type IN (71, 207, 218)
          LIMIT 1
      ) AND NOT EXISTS (
        SELECT TRUE FROM track WHERE track.recording = outer_r.id LIMIT 1
      ) AND NOT EXISTS (
        SELECT TRUE FROM l_area_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_artist_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_event_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_instrument_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_label_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_place_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_recording WHERE entity1 = outer_r.id OR entity0 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_release WHERE entity0 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_release_group WHERE entity0 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_series WHERE entity0 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_work WHERE entity0 = outer_r.id
          UNION ALL
         SELECT TRUE FROM l_recording_url WHERE entity0 = outer_r.id
      );

    IF FOUND THEN
      -- Remove references from tables that don't change whether or not this recording
      -- is orphaned.
      DELETE FROM isrc WHERE recording = OLD.recording;
      DELETE FROM recording_alias WHERE recording = OLD.recording;
      DELETE FROM recording_annotation WHERE recording = OLD.recording;
      DELETE FROM recording_gid_redirect WHERE new_id = OLD.recording;
      DELETE FROM recording_rating_raw WHERE recording = OLD.recording;
      DELETE FROM recording_tag WHERE recording = OLD.recording;
      DELETE FROM recording_tag_raw WHERE recording = OLD.recording;

      DELETE FROM recording WHERE id = OLD.recording;
    END IF;

    RETURN NULL;
  END;
$$;



CREATE FUNCTION musicbrainz.delete_ratings(enttype text, ids integer[]) RETURNS TABLE(editor integer, rating smallint)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    tablename TEXT;
BEGIN
    tablename = enttype || '_rating_raw';
    RETURN QUERY
       EXECUTE 'DELETE FROM ' || tablename || ' WHERE ' || enttype || ' = any($1)
                RETURNING editor, rating'
         USING ids;
    RETURN;
END;
$_$;



CREATE FUNCTION musicbrainz.delete_unused_tag(tag_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
  BEGIN
    DELETE FROM tag WHERE id = tag_id;
  EXCEPTION
    WHEN foreign_key_violation THEN RETURN;
  END;
$$;



CREATE FUNCTION musicbrainz.delete_unused_url(ids integer[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  clear_up INTEGER[];
BEGIN
  SELECT ARRAY(
    SELECT id FROM url url_row WHERE id = any(ids)
    EXCEPT
    SELECT url FROM edit_url JOIN edit ON (edit.id = edit_url.edit) WHERE edit.status = 1
    EXCEPT
    SELECT entity1 FROM l_area_url
    EXCEPT
    SELECT entity1 FROM l_artist_url
    EXCEPT
    SELECT entity1 FROM l_event_url
    EXCEPT
    SELECT entity1 FROM l_instrument_url
    EXCEPT
    SELECT entity1 FROM l_label_url
    EXCEPT
    SELECT entity1 FROM l_place_url
    EXCEPT
    SELECT entity1 FROM l_recording_url
    EXCEPT
    SELECT entity1 FROM l_release_url
    EXCEPT
    SELECT entity1 FROM l_release_group_url
    EXCEPT
    SELECT entity1 FROM l_series_url
    EXCEPT
    SELECT entity1 FROM l_url_url
    EXCEPT
    SELECT entity0 FROM l_url_url
    EXCEPT
    SELECT entity0 FROM l_url_work
  ) INTO clear_up;

  DELETE FROM url_gid_redirect WHERE new_id = any(clear_up);
  DELETE FROM url WHERE id = any(clear_up);
END;
$$;



CREATE FUNCTION musicbrainz.deny_deprecated_links() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.link_type <> NEW.link_type))
    AND (SELECT is_deprecated FROM link_type WHERE id = NEW.link_type)
  THEN
    RAISE EXCEPTION 'Attempt to create or change a relationship into a deprecated relationship type';
  END IF;
  RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.deny_special_purpose_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'Attempted to delete a special purpose row';
END;
$$;



CREATE FUNCTION musicbrainz.end_area_implies_ended() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.end_area IS NOT NULL
    THEN
        NEW.ended = TRUE;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.end_date_implies_ended() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.end_date_year IS NOT NULL OR
       NEW.end_date_month IS NOT NULL OR
       NEW.end_date_day IS NOT NULL
    THEN
        NEW.ended = TRUE;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.ensure_area_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.area_attribute_text IS NOT NULL
        AND NOT EXISTS (
            SELECT TRUE
              FROM area_attribute_type
             WHERE area_attribute_type.id = NEW.area_attribute_type
               AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.ensure_artist_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.artist_attribute_text IS NOT NULL
        AND NOT EXISTS (
            SELECT TRUE
              FROM artist_attribute_type
             WHERE artist_attribute_type.id = NEW.artist_attribute_type
               AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.ensure_event_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.event_attribute_text IS NOT NULL
        AND NOT EXISTS (
            SELECT TRUE
              FROM event_attribute_type
             WHERE event_attribute_type.id = NEW.event_attribute_type
               AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.ensure_instrument_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.instrument_attribute_text IS NOT NULL
        AND NOT EXISTS (
            SELECT TRUE
              FROM instrument_attribute_type
             WHERE instrument_attribute_type.id = NEW.instrument_attribute_type
               AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.ensure_label_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.label_attribute_text IS NOT NULL
        AND NOT EXISTS (
            SELECT TRUE
              FROM label_attribute_type
             WHERE label_attribute_type.id = NEW.label_attribute_type
               AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.ensure_medium_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.medium_attribute_text IS NOT NULL
        AND NOT EXISTS (
            SELECT TRUE
              FROM medium_attribute_type
             WHERE medium_attribute_type.id = NEW.medium_attribute_type
               AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.ensure_place_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.place_attribute_text IS NOT NULL
        AND NOT EXISTS (
            SELECT TRUE
              FROM place_attribute_type
             WHERE place_attribute_type.id = NEW.place_attribute_type
               AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.ensure_recording_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.recording_attribute_text IS NOT NULL
        AND NOT EXISTS (
            SELECT TRUE
              FROM recording_attribute_type
             WHERE recording_attribute_type.id = NEW.recording_attribute_type
               AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.ensure_release_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.release_attribute_text IS NOT NULL
        AND NOT EXISTS (
            SELECT TRUE
              FROM release_attribute_type
             WHERE release_attribute_type.id = NEW.release_attribute_type
               AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.ensure_release_group_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    IF NEW.release_group_attribute_text IS NOT NULL
        AND NOT EXISTS (
           SELECT TRUE FROM release_group_attribute_type
        WHERE release_group_attribute_type.id = NEW.release_group_attribute_type
        AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE RETURN NEW;
    END IF;
  END;
$$;



CREATE FUNCTION musicbrainz.ensure_series_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.series_attribute_text IS NOT NULL
        AND NOT EXISTS (
            SELECT TRUE
              FROM series_attribute_type
             WHERE series_attribute_type.id = NEW.series_attribute_type
               AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.ensure_work_attribute_type_allows_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.work_attribute_text IS NOT NULL
        AND NOT EXISTS (
            SELECT TRUE FROM work_attribute_type
             WHERE work_attribute_type.id = NEW.work_attribute_type
               AND free_text
    )
    THEN
        RAISE EXCEPTION 'This attribute type can not contain free text';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;



CREATE FUNCTION musicbrainz.from_hex(t text) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN EXECUTE 'SELECT x'''||t||'''::integer AS hex' LOOP
        RETURN r.hex;
    END LOOP;
END
$$;



CREATE FUNCTION musicbrainz.generate_uuid_v3(namespace character varying, name character varying) RETURNS uuid
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    value varchar(36);
    bytes varchar;
BEGIN
    bytes = md5(decode(namespace, 'hex') || decode(name, 'escape'));
    value = substr(bytes, 1+0, 8);
    value = value || '-';
    value = value || substr(bytes, 1+2*4, 4);
    value = value || '-';
    value = value || lpad(to_hex((from_hex(substr(bytes, 1+2*6, 2)) & 15) | 48), 2, '0');
    value = value || substr(bytes, 1+2*7, 2);
    value = value || '-';
    value = value || lpad(to_hex((from_hex(substr(bytes, 1+2*8, 2)) & 63) | 128), 2, '0');
    value = value || substr(bytes, 1+2*9, 2);
    value = value || '-';
    value = value || substr(bytes, 1+2*10, 12);
    return value::uuid;
END;
$$;



CREATE FUNCTION musicbrainz.generate_uuid_v4() RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    value VARCHAR(36);
BEGIN
    value =          lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || '-';
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || '-';
    value = value || lpad((to_hex((ceil(random() * 255)::int & 15) | 64)), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || '-';
    value = value || lpad((to_hex((ceil(random() * 255)::int & 63) | 128)), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || '-';
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    RETURN value::uuid;
END;
$$;



CREATE FUNCTION musicbrainz.inc_nullable_artist_credit(row_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF row_id IS NOT NULL THEN
        PERFORM inc_ref_count('artist_credit', row_id, 1);
    END IF;
    RETURN;
END;
$$;



CREATE FUNCTION musicbrainz.inc_ref_count(tbl character varying, row_id integer, val integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- increment ref_count for the new name
    EXECUTE 'SELECT ref_count FROM ' || tbl || ' WHERE id = ' || row_id || ' FOR UPDATE';
    EXECUTE 'UPDATE ' || tbl || ' SET ref_count = ref_count + ' || val || ' WHERE id = ' || row_id;
    RETURN;
END;
$$;



CREATE FUNCTION musicbrainz.inserting_edits_requires_confirmed_email_address() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT (
    SELECT email_confirm_date IS NOT NULL AND email_confirm_date <= now()
    FROM editor
    WHERE editor.id = NEW.editor
  ) THEN
    RAISE EXCEPTION 'Editor tried to create edit without a confirmed email address';
  ELSE
    RETURN NEW;
  END IF;
END;
$$;



CREATE FUNCTION musicbrainz.materialise_recording_length(recording_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE recording SET length = median
   FROM (SELECT median_track_length(recording_id) median) track
  WHERE recording.id = recording_id
    AND recording.length IS DISTINCT FROM track.median;
END;
$$;



CREATE FUNCTION musicbrainz.median_track_length(recording_id integer) RETURNS integer
    LANGUAGE sql
    AS $_$
  SELECT median(track.length) FROM track WHERE recording = $1;
$_$;



CREATE FUNCTION musicbrainz.padded_by_whitespace(text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
  SELECT btrim($1) <> $1;
$_$;



CREATE FUNCTION musicbrainz.prevent_invalid_attributes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT TRUE
        FROM (VALUES (NEW.link, NEW.attribute_type)) la (link, attribute_type)
        JOIN link l ON l.id = la.link
        JOIN link_type lt ON l.link_type = lt.id
        JOIN link_attribute_type lat ON lat.id = la.attribute_type
        JOIN link_type_attribute_type ltat ON ltat.attribute_type = lat.root AND ltat.link_type = lt.id
    ) THEN
        RAISE EXCEPTION 'Attribute type % is invalid for link %', NEW.attribute_type, NEW.link;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.remove_unused_links() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    other_ars_exist BOOLEAN;
BEGIN
    EXECUTE 'SELECT EXISTS (SELECT TRUE FROM ' || quote_ident(TG_TABLE_NAME) ||
            ' WHERE link = $1)'
    INTO other_ars_exist
    USING OLD.link;

    IF NOT other_ars_exist THEN
       DELETE FROM link_attribute WHERE link = OLD.link;
       DELETE FROM link_attribute_credit WHERE link = OLD.link;
       DELETE FROM link_attribute_text_value WHERE link = OLD.link;
       DELETE FROM link WHERE id = OLD.link;
    END IF;

    RETURN NULL;
END;
$_$;



CREATE FUNCTION musicbrainz.remove_unused_url() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_TABLE_NAME LIKE 'l_url_%' THEN
      EXECUTE delete_unused_url(ARRAY[OLD.entity0]);
    END IF;

    IF TG_TABLE_NAME LIKE 'l_%_url' THEN
      EXECUTE delete_unused_url(ARRAY[OLD.entity1]);
    END IF;

    IF TG_TABLE_NAME LIKE 'url' THEN
      EXECUTE delete_unused_url(ARRAY[OLD.id, NEW.id]);
    END IF;

    RETURN NULL;
END;
$$;



CREATE FUNCTION musicbrainz.replace_old_sub_on_add() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    UPDATE editor_subscribe_collection
     SET available = TRUE, last_seen_name = NULL,
      last_edit_sent = NEW.last_edit_sent
     WHERE editor = NEW.editor AND collection = NEW.collection;

    IF FOUND THEN
      RETURN NULL;
    ELSE
      RETURN NEW;
    END IF;
  END;
$$;



CREATE FUNCTION musicbrainz.set_release_group_first_release_date(release_group_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE release_group_meta SET first_release_date_year = first.date_year,
                                  first_release_date_month = first.date_month,
                                  first_release_date_day = first.date_day
      FROM (
        SELECT date_year, date_month, date_day
        FROM (
          SELECT date_year, date_month, date_day
          FROM release
          LEFT JOIN release_country ON (release_country.release = release.id)
          WHERE release.release_group = release_group_id
          UNION
          SELECT date_year, date_month, date_day
          FROM release
          LEFT JOIN release_unknown_country ON (release_unknown_country.release = release.id)
          WHERE release.release_group = release_group_id
        ) b
        ORDER BY date_year NULLS LAST, date_month NULLS LAST, date_day NULLS LAST
        LIMIT 1
      ) AS first
    WHERE id = release_group_id;
END;
$$;



CREATE FUNCTION musicbrainz.simplify_search_hints() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.type::int = TG_ARGV[0]::int THEN
        NEW.sort_name := NEW.name;
        NEW.begin_date_year := NULL;
        NEW.begin_date_month := NULL;
        NEW.begin_date_day := NULL;
        NEW.end_date_year := NULL;
        NEW.end_date_month := NULL;
        NEW.end_date_day := NULL;
        NEW.end_date_day := NULL;
        NEW.ended := FALSE;
        NEW.locale := NULL;
    END IF;
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_with_oids = false;


CREATE TABLE musicbrainz.medium (
    id integer NOT NULL,
    release integer NOT NULL,
    "position" integer NOT NULL,
    format integer,
    name character varying DEFAULT ''::character varying NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    track_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT medium_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE FUNCTION musicbrainz.track_count_matches_cdtoc(musicbrainz.medium, integer) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT $1.track_count = $2 + COALESCE(
        (SELECT count(*) FROM track
         WHERE medium = $1.id AND (position = 0 OR is_data_track = true)
    ), 0);
$_$;



CREATE FUNCTION musicbrainz.trg_delete_unused_tag() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    PERFORM delete_unused_tag(NEW.id);
    RETURN NULL;
  END;
$$;



CREATE FUNCTION musicbrainz.trg_delete_unused_tag_ref() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    PERFORM delete_unused_tag(OLD.tag);
    RETURN NULL;
  END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_area_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE area_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND area = NEW.area;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_artist_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE artist_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND artist = NEW.artist;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_event_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE event_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND event = NEW.event;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_genre_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE genre_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND genre = NEW.genre;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_instrument_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE instrument_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND instrument = NEW.instrument;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_label_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE label_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND label = NEW.label;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_place_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE place_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND place = NEW.place;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_recording_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE recording_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND recording = NEW.recording;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_release_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE release_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND release = NEW.release;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_release_group_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE release_group_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND release_group = NEW.release_group;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_series_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE series_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND series = NEW.series;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.unique_primary_work_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.primary_for_locale THEN
      UPDATE work_alias SET primary_for_locale = FALSE
      WHERE locale = NEW.locale AND id != NEW.id
        AND work = NEW.work;
    END IF;
    RETURN NEW;
END;
$$;



CREATE FUNCTION musicbrainz.whitespace_collapsed(text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
  SELECT $1 !~ E'\\s{2,}';
$_$;



CREATE AGGREGATE musicbrainz.array_accum(anyelement) (
    SFUNC = array_append,
    STYPE = anyarray,
    INITCOND = '{}'
);



CREATE AGGREGATE musicbrainz.median(anyelement) (
    SFUNC = array_append,
    STYPE = anyarray,
    INITCOND = '{}',
    FINALFUNC = musicbrainz._median
);



CREATE TABLE cover_art_archive.art_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE cover_art_archive.art_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE cover_art_archive.art_type_id_seq OWNED BY cover_art_archive.art_type.id;



CREATE TABLE cover_art_archive.cover_art (
    id bigint NOT NULL,
    release integer NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    edit integer NOT NULL,
    ordering integer NOT NULL,
    date_uploaded timestamp with time zone DEFAULT now() NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    mime_type text NOT NULL,
    filesize integer,
    thumb_250_filesize integer,
    thumb_500_filesize integer,
    thumb_1200_filesize integer,
    CONSTRAINT cover_art_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT cover_art_ordering_check CHECK ((ordering > 0))
);



CREATE TABLE cover_art_archive.cover_art_type (
    id bigint NOT NULL,
    type_id integer NOT NULL
);



CREATE TABLE cover_art_archive.image_type (
    mime_type text NOT NULL,
    suffix text NOT NULL
);



CREATE TABLE cover_art_archive.release_group_cover_art (
    release_group integer NOT NULL,
    release integer NOT NULL
);



CREATE TABLE documentation.l_area_area_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_area_artist_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_area_event_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_area_instrument_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_area_label_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_area_place_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_area_recording_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_area_release_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_area_release_group_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_area_series_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_area_url_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_area_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_artist_artist_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_artist_event_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_artist_instrument_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_artist_label_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_artist_place_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_artist_recording_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_artist_release_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_artist_release_group_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_artist_series_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_artist_url_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_artist_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_event_event_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_event_instrument_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_event_label_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_event_place_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_event_recording_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_event_release_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_event_release_group_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_event_series_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_event_url_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_event_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_instrument_instrument_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_instrument_label_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_instrument_place_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_instrument_recording_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_instrument_release_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_instrument_release_group_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_instrument_series_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_instrument_url_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_instrument_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_label_label_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_label_place_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_label_recording_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_label_release_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_label_release_group_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_label_series_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_label_url_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_label_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_place_place_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_place_recording_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_place_release_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_place_release_group_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_place_series_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_place_url_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_place_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_recording_recording_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_recording_release_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_recording_release_group_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_recording_series_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_recording_url_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_recording_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_release_group_release_group_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_release_group_series_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_release_group_url_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_release_group_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_release_release_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_release_release_group_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_release_series_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_release_url_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_release_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_series_series_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_series_url_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_series_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_url_url_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_url_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.l_work_work_example (
    id integer NOT NULL,
    published boolean NOT NULL,
    name text NOT NULL
);



CREATE TABLE documentation.link_type_documentation (
    id integer NOT NULL,
    documentation text NOT NULL,
    examples_deleted smallint DEFAULT 0 NOT NULL
);



CREATE TABLE event_art_archive.art_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE event_art_archive.art_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE event_art_archive.art_type_id_seq OWNED BY event_art_archive.art_type.id;



CREATE TABLE event_art_archive.event_art (
    id bigint NOT NULL,
    event integer NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    edit integer NOT NULL,
    ordering integer NOT NULL,
    date_uploaded timestamp with time zone DEFAULT now() NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    mime_type text NOT NULL,
    filesize integer,
    thumb_250_filesize integer,
    thumb_500_filesize integer,
    thumb_1200_filesize integer,
    CONSTRAINT event_art_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT event_art_ordering_check CHECK ((ordering > 0))
);



CREATE TABLE event_art_archive.event_art_type (
    id bigint NOT NULL,
    type_id integer NOT NULL
);



CREATE TABLE musicbrainz.alternative_medium (
    id integer NOT NULL,
    medium integer NOT NULL,
    alternative_release integer NOT NULL,
    name character varying,
    CONSTRAINT alternative_medium_name_check CHECK (((name)::text <> ''::text))
);



CREATE SEQUENCE musicbrainz.alternative_medium_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.alternative_medium_id_seq OWNED BY musicbrainz.alternative_medium.id;



CREATE TABLE musicbrainz.alternative_medium_track (
    alternative_medium integer NOT NULL,
    track integer NOT NULL,
    alternative_track integer NOT NULL
);



CREATE TABLE musicbrainz.alternative_release (
    id integer NOT NULL,
    gid uuid NOT NULL,
    release integer NOT NULL,
    name character varying,
    artist_credit integer,
    type integer NOT NULL,
    language integer NOT NULL,
    script integer NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT alternative_release_name_check CHECK (((name)::text <> ''::text))
);



CREATE SEQUENCE musicbrainz.alternative_release_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.alternative_release_id_seq OWNED BY musicbrainz.alternative_release.id;



CREATE TABLE musicbrainz.alternative_release_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.alternative_release_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.alternative_release_type_id_seq OWNED BY musicbrainz.alternative_release_type.id;



CREATE TABLE musicbrainz.alternative_track (
    id integer NOT NULL,
    name character varying,
    artist_credit integer,
    ref_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT alternative_track_check CHECK ((((name)::text <> ''::text) AND ((name IS NOT NULL) OR (artist_credit IS NOT NULL))))
);



CREATE SEQUENCE musicbrainz.alternative_track_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.alternative_track_id_seq OWNED BY musicbrainz.alternative_track.id;



CREATE TABLE musicbrainz.annotation (
    id integer NOT NULL,
    editor integer NOT NULL,
    text text,
    changelog character varying(255),
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.annotation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.annotation_id_seq OWNED BY musicbrainz.annotation.id;



CREATE TABLE musicbrainz.application (
    id integer NOT NULL,
    owner integer NOT NULL,
    name text NOT NULL,
    oauth_id text NOT NULL,
    oauth_secret text NOT NULL,
    oauth_redirect_uri text
);



CREATE SEQUENCE musicbrainz.application_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.application_id_seq OWNED BY musicbrainz.application.id;



CREATE TABLE musicbrainz.area (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    type integer,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    ended boolean DEFAULT false NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT area_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT area_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE TABLE musicbrainz.area_alias (
    id integer NOT NULL,
    area integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    type integer,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    primary_for_locale boolean DEFAULT false NOT NULL,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT area_alias_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT area_alias_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL)))
);



CREATE SEQUENCE musicbrainz.area_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.area_alias_id_seq OWNED BY musicbrainz.area_alias.id;



CREATE TABLE musicbrainz.area_alias_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.area_alias_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.area_alias_type_id_seq OWNED BY musicbrainz.area_alias_type.id;



CREATE TABLE musicbrainz.area_annotation (
    area integer NOT NULL,
    annotation integer NOT NULL
);



CREATE TABLE musicbrainz.area_attribute (
    id integer NOT NULL,
    area integer NOT NULL,
    area_attribute_type integer NOT NULL,
    area_attribute_type_allowed_value integer,
    area_attribute_text text,
    CONSTRAINT area_attribute_check CHECK ((((area_attribute_type_allowed_value IS NULL) AND (area_attribute_text IS NOT NULL)) OR ((area_attribute_type_allowed_value IS NOT NULL) AND (area_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.area_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.area_attribute_id_seq OWNED BY musicbrainz.area_attribute.id;



CREATE TABLE musicbrainz.area_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.area_attribute_type_allowed_value (
    id integer NOT NULL,
    area_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.area_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.area_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.area_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.area_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.area_attribute_type_id_seq OWNED BY musicbrainz.area_attribute_type.id;



CREATE TABLE musicbrainz.area_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.area_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.area_id_seq OWNED BY musicbrainz.area.id;



CREATE TABLE musicbrainz.area_tag (
    area integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.area_tag_raw (
    area integer NOT NULL,
    editor integer NOT NULL,
    tag integer NOT NULL,
    is_upvote boolean DEFAULT true NOT NULL
);



CREATE TABLE musicbrainz.area_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.area_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.area_type_id_seq OWNED BY musicbrainz.area_type.id;



CREATE TABLE musicbrainz.artist (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    type integer,
    area integer,
    gender integer,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    ended boolean DEFAULT false NOT NULL,
    begin_area integer,
    end_area integer,
    CONSTRAINT artist_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT artist_ended_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL))))
);



CREATE TABLE musicbrainz.artist_alias (
    id integer NOT NULL,
    artist integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    type integer,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    primary_for_locale boolean DEFAULT false NOT NULL,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT artist_alias_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT artist_alias_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL))),
    CONSTRAINT search_hints_are_empty CHECK (((type <> 3) OR ((type = 3) AND ((sort_name)::text = (name)::text) AND (begin_date_year IS NULL) AND (begin_date_month IS NULL) AND (begin_date_day IS NULL) AND (end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL) AND (primary_for_locale IS FALSE) AND (locale IS NULL))))
);



CREATE SEQUENCE musicbrainz.artist_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.artist_alias_id_seq OWNED BY musicbrainz.artist_alias.id;



CREATE TABLE musicbrainz.artist_alias_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.artist_alias_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.artist_alias_type_id_seq OWNED BY musicbrainz.artist_alias_type.id;



CREATE TABLE musicbrainz.artist_annotation (
    artist integer NOT NULL,
    annotation integer NOT NULL
);



CREATE TABLE musicbrainz.artist_attribute (
    id integer NOT NULL,
    artist integer NOT NULL,
    artist_attribute_type integer NOT NULL,
    artist_attribute_type_allowed_value integer,
    artist_attribute_text text,
    CONSTRAINT artist_attribute_check CHECK ((((artist_attribute_type_allowed_value IS NULL) AND (artist_attribute_text IS NOT NULL)) OR ((artist_attribute_type_allowed_value IS NOT NULL) AND (artist_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.artist_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.artist_attribute_id_seq OWNED BY musicbrainz.artist_attribute.id;



CREATE TABLE musicbrainz.artist_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.artist_attribute_type_allowed_value (
    id integer NOT NULL,
    artist_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.artist_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.artist_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.artist_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.artist_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.artist_attribute_type_id_seq OWNED BY musicbrainz.artist_attribute_type.id;



CREATE TABLE musicbrainz.artist_credit (
    id integer NOT NULL,
    name character varying NOT NULL,
    artist_count smallint NOT NULL,
    ref_count integer DEFAULT 0,
    created timestamp with time zone DEFAULT now(),
    edits_pending integer DEFAULT 0 NOT NULL,
    CONSTRAINT artist_credit_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE SEQUENCE musicbrainz.artist_credit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.artist_credit_id_seq OWNED BY musicbrainz.artist_credit.id;



CREATE TABLE musicbrainz.artist_credit_name (
    artist_credit integer NOT NULL,
    "position" smallint NOT NULL,
    artist integer NOT NULL,
    name character varying NOT NULL,
    join_phrase text DEFAULT ''::text NOT NULL
);



CREATE TABLE musicbrainz.artist_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.artist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.artist_id_seq OWNED BY musicbrainz.artist.id;



CREATE TABLE musicbrainz.artist_ipi (
    artist integer NOT NULL,
    ipi character(11) NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    created timestamp with time zone DEFAULT now(),
    CONSTRAINT artist_ipi_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT artist_ipi_ipi_check CHECK ((ipi ~ '^\d{11}$'::text))
);



CREATE TABLE musicbrainz.artist_isni (
    artist integer NOT NULL,
    isni character(16) NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    created timestamp with time zone DEFAULT now(),
    CONSTRAINT artist_isni_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT artist_isni_isni_check CHECK ((isni ~ '^\d{15}[\dX]$'::text))
);



CREATE TABLE musicbrainz.artist_meta (
    id integer NOT NULL,
    rating smallint,
    rating_count integer,
    CONSTRAINT artist_meta_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE TABLE musicbrainz.artist_rating_raw (
    artist integer NOT NULL,
    editor integer NOT NULL,
    rating smallint NOT NULL,
    CONSTRAINT artist_rating_raw_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE TABLE musicbrainz.artist_tag (
    artist integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.artist_tag_raw (
    artist integer NOT NULL,
    editor integer NOT NULL,
    tag integer NOT NULL,
    is_upvote boolean DEFAULT true NOT NULL
);



CREATE TABLE musicbrainz.artist_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.artist_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.artist_type_id_seq OWNED BY musicbrainz.artist_type.id;



CREATE TABLE musicbrainz.autoeditor_election (
    id integer NOT NULL,
    candidate integer NOT NULL,
    proposer integer NOT NULL,
    seconder_1 integer,
    seconder_2 integer,
    status integer DEFAULT 1 NOT NULL,
    yes_votes integer DEFAULT 0 NOT NULL,
    no_votes integer DEFAULT 0 NOT NULL,
    propose_time timestamp with time zone DEFAULT now() NOT NULL,
    open_time timestamp with time zone,
    close_time timestamp with time zone,
    CONSTRAINT autoeditor_election_status_check CHECK ((status = ANY (ARRAY[1, 2, 3, 4, 5, 6])))
);



CREATE SEQUENCE musicbrainz.autoeditor_election_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.autoeditor_election_id_seq OWNED BY musicbrainz.autoeditor_election.id;



CREATE TABLE musicbrainz.autoeditor_election_vote (
    id integer NOT NULL,
    autoeditor_election integer NOT NULL,
    voter integer NOT NULL,
    vote integer NOT NULL,
    vote_time timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT autoeditor_election_vote_vote_check CHECK ((vote = ANY (ARRAY['-1'::integer, 0, 1])))
);



CREATE SEQUENCE musicbrainz.autoeditor_election_vote_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.autoeditor_election_vote_id_seq OWNED BY musicbrainz.autoeditor_election_vote.id;



CREATE TABLE musicbrainz.cdtoc (
    id integer NOT NULL,
    discid character(28) NOT NULL,
    freedb_id character(8) NOT NULL,
    track_count integer NOT NULL,
    leadout_offset integer NOT NULL,
    track_offset integer[] NOT NULL,
    degraded boolean DEFAULT false NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.cdtoc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.cdtoc_id_seq OWNED BY musicbrainz.cdtoc.id;



CREATE TABLE musicbrainz.cdtoc_raw (
    id integer NOT NULL,
    release integer NOT NULL,
    discid character(28) NOT NULL,
    track_count integer NOT NULL,
    leadout_offset integer NOT NULL,
    track_offset integer[] NOT NULL
);



CREATE SEQUENCE musicbrainz.cdtoc_raw_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.cdtoc_raw_id_seq OWNED BY musicbrainz.cdtoc_raw.id;



CREATE TABLE musicbrainz.country_area (
    area integer NOT NULL
);



CREATE TABLE musicbrainz.deleted_entity (
    gid uuid NOT NULL,
    data jsonb NOT NULL,
    deleted_at timestamp with time zone DEFAULT now() NOT NULL
);



CREATE TABLE musicbrainz.edit (
    id integer NOT NULL,
    editor integer NOT NULL,
    type smallint NOT NULL,
    status smallint NOT NULL,
    autoedit smallint DEFAULT 0 NOT NULL,
    open_time timestamp with time zone DEFAULT now(),
    close_time timestamp with time zone,
    expire_time timestamp with time zone NOT NULL,
    language integer,
    quality smallint DEFAULT 1 NOT NULL
);



CREATE TABLE musicbrainz.edit_area (
    edit integer NOT NULL,
    area integer NOT NULL
);



CREATE TABLE musicbrainz.edit_artist (
    edit integer NOT NULL,
    artist integer NOT NULL,
    status smallint NOT NULL
);



CREATE TABLE musicbrainz.edit_data (
    edit integer NOT NULL,
    data jsonb NOT NULL
);



CREATE TABLE musicbrainz.edit_event (
    edit integer NOT NULL,
    event integer NOT NULL
);



CREATE SEQUENCE musicbrainz.edit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.edit_id_seq OWNED BY musicbrainz.edit.id;



CREATE TABLE musicbrainz.edit_instrument (
    edit integer NOT NULL,
    instrument integer NOT NULL
);



CREATE TABLE musicbrainz.edit_label (
    edit integer NOT NULL,
    label integer NOT NULL,
    status smallint NOT NULL
);



CREATE TABLE musicbrainz.edit_note (
    id integer NOT NULL,
    editor integer NOT NULL,
    edit integer NOT NULL,
    text text NOT NULL,
    post_time timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.edit_note_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.edit_note_id_seq OWNED BY musicbrainz.edit_note.id;



CREATE TABLE musicbrainz.edit_note_recipient (
    recipient integer NOT NULL,
    edit_note integer NOT NULL
);



CREATE TABLE musicbrainz.edit_place (
    edit integer NOT NULL,
    place integer NOT NULL
);



CREATE TABLE musicbrainz.edit_recording (
    edit integer NOT NULL,
    recording integer NOT NULL
);



CREATE TABLE musicbrainz.edit_release (
    edit integer NOT NULL,
    release integer NOT NULL
);



CREATE TABLE musicbrainz.edit_release_group (
    edit integer NOT NULL,
    release_group integer NOT NULL
);



CREATE TABLE musicbrainz.edit_series (
    edit integer NOT NULL,
    series integer NOT NULL
);



CREATE TABLE musicbrainz.edit_url (
    edit integer NOT NULL,
    url integer NOT NULL
);



CREATE TABLE musicbrainz.edit_work (
    edit integer NOT NULL,
    work integer NOT NULL
);



CREATE TABLE musicbrainz.editor (
    id integer NOT NULL,
    name character varying(64) NOT NULL,
    privs integer DEFAULT 0,
    email character varying(64) DEFAULT NULL::character varying,
    website character varying(255) DEFAULT NULL::character varying,
    bio text,
    member_since timestamp with time zone DEFAULT now(),
    email_confirm_date timestamp with time zone,
    last_login_date timestamp with time zone DEFAULT now(),
    last_updated timestamp with time zone DEFAULT now(),
    birth_date date,
    gender integer,
    area integer,
    password character varying(128) NOT NULL,
    ha1 character(32) NOT NULL,
    deleted boolean DEFAULT false NOT NULL
);



CREATE TABLE musicbrainz.editor_collection (
    id integer NOT NULL,
    gid uuid NOT NULL,
    editor integer NOT NULL,
    name character varying NOT NULL,
    public boolean DEFAULT false NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    type integer NOT NULL
);



CREATE TABLE musicbrainz.editor_collection_area (
    collection integer NOT NULL,
    area integer NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_area_position_check CHECK (("position" >= 0))
);



CREATE TABLE musicbrainz.editor_collection_artist (
    collection integer NOT NULL,
    artist integer NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_artist_position_check CHECK (("position" >= 0))
);



CREATE TABLE musicbrainz.editor_collection_collaborator (
    collection integer NOT NULL,
    editor integer NOT NULL
);



CREATE TABLE musicbrainz.editor_collection_deleted_entity (
    collection integer NOT NULL,
    gid uuid NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_deleted_entity_position_check CHECK (("position" >= 0))
);



CREATE TABLE musicbrainz.editor_collection_event (
    collection integer NOT NULL,
    event integer NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_event_position_check CHECK (("position" >= 0))
);



CREATE SEQUENCE musicbrainz.editor_collection_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.editor_collection_id_seq OWNED BY musicbrainz.editor_collection.id;



CREATE TABLE musicbrainz.editor_collection_instrument (
    collection integer NOT NULL,
    instrument integer NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_instrument_position_check CHECK (("position" >= 0))
);



CREATE TABLE musicbrainz.editor_collection_label (
    collection integer NOT NULL,
    label integer NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_label_position_check CHECK (("position" >= 0))
);



CREATE TABLE musicbrainz.editor_collection_place (
    collection integer NOT NULL,
    place integer NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_place_position_check CHECK (("position" >= 0))
);



CREATE TABLE musicbrainz.editor_collection_recording (
    collection integer NOT NULL,
    recording integer NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_recording_position_check CHECK (("position" >= 0))
);



CREATE TABLE musicbrainz.editor_collection_release (
    collection integer NOT NULL,
    release integer NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_release_position_check CHECK (("position" >= 0))
);



CREATE TABLE musicbrainz.editor_collection_release_group (
    collection integer NOT NULL,
    release_group integer NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_release_group_position_check CHECK (("position" >= 0))
);



CREATE TABLE musicbrainz.editor_collection_series (
    collection integer NOT NULL,
    series integer NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_series_position_check CHECK (("position" >= 0))
);



CREATE TABLE musicbrainz.editor_collection_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    entity_type character varying(50) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.editor_collection_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.editor_collection_type_id_seq OWNED BY musicbrainz.editor_collection_type.id;



CREATE TABLE musicbrainz.editor_collection_work (
    collection integer NOT NULL,
    work integer NOT NULL,
    added timestamp with time zone DEFAULT now(),
    "position" integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    CONSTRAINT editor_collection_work_position_check CHECK (("position" >= 0))
);



CREATE SEQUENCE musicbrainz.editor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.editor_id_seq OWNED BY musicbrainz.editor.id;



CREATE TABLE musicbrainz.editor_language (
    editor integer NOT NULL,
    language integer NOT NULL,
    fluency musicbrainz.fluency NOT NULL
);



CREATE TABLE musicbrainz.editor_oauth_token (
    id integer NOT NULL,
    editor integer NOT NULL,
    application integer NOT NULL,
    authorization_code text,
    refresh_token text,
    access_token text,
    expire_time timestamp with time zone NOT NULL,
    scope integer DEFAULT 0 NOT NULL,
    granted timestamp with time zone DEFAULT now() NOT NULL
);



CREATE SEQUENCE musicbrainz.editor_oauth_token_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.editor_oauth_token_id_seq OWNED BY musicbrainz.editor_oauth_token.id;



CREATE TABLE musicbrainz.editor_preference (
    id integer NOT NULL,
    editor integer NOT NULL,
    name character varying(50) NOT NULL,
    value character varying(100) NOT NULL
);



CREATE SEQUENCE musicbrainz.editor_preference_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.editor_preference_id_seq OWNED BY musicbrainz.editor_preference.id;



CREATE TABLE musicbrainz.editor_subscribe_artist (
    id integer NOT NULL,
    editor integer NOT NULL,
    artist integer NOT NULL,
    last_edit_sent integer NOT NULL
);



CREATE TABLE musicbrainz.editor_subscribe_artist_deleted (
    editor integer NOT NULL,
    gid uuid NOT NULL,
    deleted_by integer NOT NULL
);



CREATE SEQUENCE musicbrainz.editor_subscribe_artist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.editor_subscribe_artist_id_seq OWNED BY musicbrainz.editor_subscribe_artist.id;



CREATE TABLE musicbrainz.editor_subscribe_collection (
    id integer NOT NULL,
    editor integer NOT NULL,
    collection integer NOT NULL,
    last_edit_sent integer NOT NULL,
    available boolean DEFAULT true NOT NULL,
    last_seen_name character varying(255)
);



CREATE SEQUENCE musicbrainz.editor_subscribe_collection_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.editor_subscribe_collection_id_seq OWNED BY musicbrainz.editor_subscribe_collection.id;



CREATE TABLE musicbrainz.editor_subscribe_editor (
    id integer NOT NULL,
    editor integer NOT NULL,
    subscribed_editor integer NOT NULL,
    last_edit_sent integer NOT NULL
);



CREATE SEQUENCE musicbrainz.editor_subscribe_editor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.editor_subscribe_editor_id_seq OWNED BY musicbrainz.editor_subscribe_editor.id;



CREATE TABLE musicbrainz.editor_subscribe_label (
    id integer NOT NULL,
    editor integer NOT NULL,
    label integer NOT NULL,
    last_edit_sent integer NOT NULL
);



CREATE TABLE musicbrainz.editor_subscribe_label_deleted (
    editor integer NOT NULL,
    gid uuid NOT NULL,
    deleted_by integer NOT NULL
);



CREATE SEQUENCE musicbrainz.editor_subscribe_label_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.editor_subscribe_label_id_seq OWNED BY musicbrainz.editor_subscribe_label.id;



CREATE TABLE musicbrainz.editor_subscribe_series (
    id integer NOT NULL,
    editor integer NOT NULL,
    series integer NOT NULL,
    last_edit_sent integer NOT NULL
);



CREATE TABLE musicbrainz.editor_subscribe_series_deleted (
    editor integer NOT NULL,
    gid uuid NOT NULL,
    deleted_by integer NOT NULL
);



CREATE SEQUENCE musicbrainz.editor_subscribe_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.editor_subscribe_series_id_seq OWNED BY musicbrainz.editor_subscribe_series.id;



CREATE TABLE musicbrainz.editor_watch_artist (
    artist integer NOT NULL,
    editor integer NOT NULL
);



CREATE TABLE musicbrainz.editor_watch_preferences (
    editor integer NOT NULL,
    notify_via_email boolean DEFAULT true NOT NULL,
    notification_timeframe interval DEFAULT '7 days'::interval NOT NULL,
    last_checked timestamp with time zone DEFAULT now() NOT NULL
);



CREATE TABLE musicbrainz.editor_watch_release_group_type (
    editor integer NOT NULL,
    release_group_type integer NOT NULL
);



CREATE TABLE musicbrainz.editor_watch_release_status (
    editor integer NOT NULL,
    release_status integer NOT NULL
);



CREATE TABLE musicbrainz.event (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    "time" time without time zone,
    type integer,
    cancelled boolean DEFAULT false NOT NULL,
    setlist text,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT event_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT event_ended_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL))))
);



CREATE TABLE musicbrainz.event_alias (
    id integer NOT NULL,
    event integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    type integer,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    primary_for_locale boolean DEFAULT false NOT NULL,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT event_alias_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT event_alias_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL))),
    CONSTRAINT search_hints_are_empty CHECK (((type <> 2) OR ((type = 2) AND ((sort_name)::text = (name)::text) AND (begin_date_year IS NULL) AND (begin_date_month IS NULL) AND (begin_date_day IS NULL) AND (end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL) AND (primary_for_locale IS FALSE) AND (locale IS NULL))))
);



CREATE SEQUENCE musicbrainz.event_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.event_alias_id_seq OWNED BY musicbrainz.event_alias.id;



CREATE TABLE musicbrainz.event_alias_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.event_alias_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.event_alias_type_id_seq OWNED BY musicbrainz.event_alias_type.id;



CREATE TABLE musicbrainz.event_annotation (
    event integer NOT NULL,
    annotation integer NOT NULL
);



CREATE TABLE musicbrainz.event_attribute (
    id integer NOT NULL,
    event integer NOT NULL,
    event_attribute_type integer NOT NULL,
    event_attribute_type_allowed_value integer,
    event_attribute_text text,
    CONSTRAINT event_attribute_check CHECK ((((event_attribute_type_allowed_value IS NULL) AND (event_attribute_text IS NOT NULL)) OR ((event_attribute_type_allowed_value IS NOT NULL) AND (event_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.event_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.event_attribute_id_seq OWNED BY musicbrainz.event_attribute.id;



CREATE TABLE musicbrainz.event_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.event_attribute_type_allowed_value (
    id integer NOT NULL,
    event_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.event_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.event_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.event_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.event_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.event_attribute_type_id_seq OWNED BY musicbrainz.event_attribute_type.id;



CREATE TABLE musicbrainz.event_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.event_id_seq OWNED BY musicbrainz.event.id;



CREATE TABLE musicbrainz.event_meta (
    id integer NOT NULL,
    rating smallint,
    rating_count integer,
    event_art_presence musicbrainz.event_art_presence DEFAULT 'absent'::musicbrainz.event_art_presence NOT NULL,
    CONSTRAINT event_meta_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE TABLE musicbrainz.event_rating_raw (
    event integer NOT NULL,
    editor integer NOT NULL,
    rating smallint NOT NULL,
    CONSTRAINT event_rating_raw_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE TABLE musicbrainz.l_event_series (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_event_series_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_event_series_link_order_check CHECK ((link_order >= 0))
);



CREATE TABLE musicbrainz.link (
    id integer NOT NULL,
    link_type integer NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    attribute_count integer DEFAULT 0 NOT NULL,
    created timestamp with time zone DEFAULT now(),
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT link_ended_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL))))
);



CREATE TABLE musicbrainz.link_attribute_text_value (
    link integer NOT NULL,
    attribute_type integer NOT NULL,
    text_value text NOT NULL
);



CREATE TABLE musicbrainz.link_type (
    id integer NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    gid uuid NOT NULL,
    entity_type0 character varying(50) NOT NULL,
    entity_type1 character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    link_phrase character varying(255) NOT NULL,
    reverse_link_phrase character varying(255) NOT NULL,
    long_link_phrase character varying(255) NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    is_deprecated boolean DEFAULT false NOT NULL,
    has_dates boolean DEFAULT true NOT NULL,
    entity0_cardinality integer DEFAULT 0 NOT NULL,
    entity1_cardinality integer DEFAULT 0 NOT NULL
);



CREATE TABLE musicbrainz.series (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    type integer NOT NULL,
    ordering_attribute integer NOT NULL,
    ordering_type integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    CONSTRAINT series_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE VIEW musicbrainz.event_series AS
 SELECT lrs.entity0 AS event,
    lrs.entity1 AS series,
    lrs.id AS relationship,
    lrs.link_order,
    lrs.link,
    COALESCE(latv.text_value, ''::text) AS text_value
   FROM ((((musicbrainz.l_event_series lrs
     JOIN musicbrainz.series s ON ((s.id = lrs.entity1)))
     JOIN musicbrainz.link l ON ((l.id = lrs.link)))
     JOIN musicbrainz.link_type lt ON (((lt.id = l.link_type) AND (lt.gid = '707d947d-9563-328a-9a7d-0c5b9c3a9791'::uuid))))
     LEFT JOIN musicbrainz.link_attribute_text_value latv ON (((latv.attribute_type = s.ordering_attribute) AND (latv.link = l.id))))
  ORDER BY lrs.entity1, lrs.link_order;



CREATE TABLE musicbrainz.event_tag (
    event integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.event_tag_raw (
    event integer NOT NULL,
    editor integer NOT NULL,
    tag integer NOT NULL,
    is_upvote boolean DEFAULT true NOT NULL
);



CREATE TABLE musicbrainz.event_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.event_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.event_type_id_seq OWNED BY musicbrainz.event_type.id;



CREATE TABLE musicbrainz.gender (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.gender_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.gender_id_seq OWNED BY musicbrainz.gender.id;



CREATE TABLE musicbrainz.genre (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    CONSTRAINT genre_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE TABLE musicbrainz.genre_alias (
    id integer NOT NULL,
    genre integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    primary_for_locale boolean DEFAULT false NOT NULL,
    CONSTRAINT genre_alias_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL)))
);



CREATE SEQUENCE musicbrainz.genre_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.genre_alias_id_seq OWNED BY musicbrainz.genre_alias.id;



CREATE SEQUENCE musicbrainz.genre_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.genre_id_seq OWNED BY musicbrainz.genre.id;



CREATE TABLE musicbrainz.instrument (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    type integer,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    CONSTRAINT instrument_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE TABLE musicbrainz.instrument_alias (
    id integer NOT NULL,
    instrument integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    type integer,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    primary_for_locale boolean DEFAULT false NOT NULL,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT instrument_alias_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT instrument_alias_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL))),
    CONSTRAINT search_hints_are_empty CHECK (((type <> 2) OR ((type = 2) AND ((sort_name)::text = (name)::text) AND (begin_date_year IS NULL) AND (begin_date_month IS NULL) AND (begin_date_day IS NULL) AND (end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL) AND (primary_for_locale IS FALSE) AND (locale IS NULL))))
);



CREATE SEQUENCE musicbrainz.instrument_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.instrument_alias_id_seq OWNED BY musicbrainz.instrument_alias.id;



CREATE TABLE musicbrainz.instrument_alias_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.instrument_alias_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.instrument_alias_type_id_seq OWNED BY musicbrainz.instrument_alias_type.id;



CREATE TABLE musicbrainz.instrument_annotation (
    instrument integer NOT NULL,
    annotation integer NOT NULL
);



CREATE TABLE musicbrainz.instrument_attribute (
    id integer NOT NULL,
    instrument integer NOT NULL,
    instrument_attribute_type integer NOT NULL,
    instrument_attribute_type_allowed_value integer,
    instrument_attribute_text text,
    CONSTRAINT instrument_attribute_check CHECK ((((instrument_attribute_type_allowed_value IS NULL) AND (instrument_attribute_text IS NOT NULL)) OR ((instrument_attribute_type_allowed_value IS NOT NULL) AND (instrument_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.instrument_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.instrument_attribute_id_seq OWNED BY musicbrainz.instrument_attribute.id;



CREATE TABLE musicbrainz.instrument_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.instrument_attribute_type_allowed_value (
    id integer NOT NULL,
    instrument_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.instrument_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.instrument_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.instrument_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.instrument_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.instrument_attribute_type_id_seq OWNED BY musicbrainz.instrument_attribute_type.id;



CREATE TABLE musicbrainz.instrument_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.instrument_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.instrument_id_seq OWNED BY musicbrainz.instrument.id;



CREATE TABLE musicbrainz.instrument_tag (
    instrument integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.instrument_tag_raw (
    instrument integer NOT NULL,
    editor integer NOT NULL,
    tag integer NOT NULL,
    is_upvote boolean DEFAULT true NOT NULL
);



CREATE TABLE musicbrainz.instrument_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.instrument_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.instrument_type_id_seq OWNED BY musicbrainz.instrument_type.id;



CREATE TABLE musicbrainz.iso_3166_1 (
    area integer NOT NULL,
    code character(2) NOT NULL
);



CREATE TABLE musicbrainz.iso_3166_2 (
    area integer NOT NULL,
    code character varying(10) NOT NULL
);



CREATE TABLE musicbrainz.iso_3166_3 (
    area integer NOT NULL,
    code character(4) NOT NULL
);



CREATE TABLE musicbrainz.isrc (
    id integer NOT NULL,
    recording integer NOT NULL,
    isrc character(12) NOT NULL,
    source smallint,
    edits_pending integer DEFAULT 0 NOT NULL,
    created timestamp with time zone DEFAULT now(),
    CONSTRAINT isrc_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT isrc_isrc_check CHECK ((isrc ~ '^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$'::text))
);



CREATE SEQUENCE musicbrainz.isrc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.isrc_id_seq OWNED BY musicbrainz.isrc.id;



CREATE TABLE musicbrainz.iswc (
    id integer NOT NULL,
    work integer NOT NULL,
    iswc character(15),
    source smallint,
    edits_pending integer DEFAULT 0 NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT iswc_iswc_check CHECK ((iswc ~ '^T-?\d{3}.?\d{3}.?\d{3}[-.]?\d$'::text))
);



CREATE SEQUENCE musicbrainz.iswc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.iswc_id_seq OWNED BY musicbrainz.iswc.id;



CREATE TABLE musicbrainz.l_area_area (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_area_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_area_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_area_area_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_area_id_seq OWNED BY musicbrainz.l_area_area.id;



CREATE TABLE musicbrainz.l_area_artist (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_artist_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_artist_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_area_artist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_artist_id_seq OWNED BY musicbrainz.l_area_artist.id;



CREATE TABLE musicbrainz.l_area_event (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_event_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_event_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_area_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_event_id_seq OWNED BY musicbrainz.l_area_event.id;



CREATE TABLE musicbrainz.l_area_instrument (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_instrument_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_instrument_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_area_instrument_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_instrument_id_seq OWNED BY musicbrainz.l_area_instrument.id;



CREATE TABLE musicbrainz.l_area_label (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_label_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_label_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_area_label_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_label_id_seq OWNED BY musicbrainz.l_area_label.id;



CREATE TABLE musicbrainz.l_area_place (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_place_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_place_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_area_place_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_place_id_seq OWNED BY musicbrainz.l_area_place.id;



CREATE TABLE musicbrainz.l_area_recording (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_recording_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_recording_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_area_recording_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_recording_id_seq OWNED BY musicbrainz.l_area_recording.id;



CREATE TABLE musicbrainz.l_area_release (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_release_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_release_link_order_check CHECK ((link_order >= 0))
);



CREATE TABLE musicbrainz.l_area_release_group (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_release_group_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_release_group_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_area_release_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_release_group_id_seq OWNED BY musicbrainz.l_area_release_group.id;



CREATE SEQUENCE musicbrainz.l_area_release_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_release_id_seq OWNED BY musicbrainz.l_area_release.id;



CREATE TABLE musicbrainz.l_area_series (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_series_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_series_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_area_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_series_id_seq OWNED BY musicbrainz.l_area_series.id;



CREATE TABLE musicbrainz.l_area_url (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_url_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_url_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_area_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_url_id_seq OWNED BY musicbrainz.l_area_url.id;



CREATE TABLE musicbrainz.l_area_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_area_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_area_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_area_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_area_work_id_seq OWNED BY musicbrainz.l_area_work.id;



CREATE TABLE musicbrainz.l_artist_artist (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_artist_artist_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_artist_artist_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_artist_artist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_artist_artist_id_seq OWNED BY musicbrainz.l_artist_artist.id;



CREATE TABLE musicbrainz.l_artist_event (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_artist_event_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_artist_event_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_artist_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_artist_event_id_seq OWNED BY musicbrainz.l_artist_event.id;



CREATE TABLE musicbrainz.l_artist_instrument (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_artist_instrument_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_artist_instrument_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_artist_instrument_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_artist_instrument_id_seq OWNED BY musicbrainz.l_artist_instrument.id;



CREATE TABLE musicbrainz.l_artist_label (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_artist_label_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_artist_label_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_artist_label_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_artist_label_id_seq OWNED BY musicbrainz.l_artist_label.id;



CREATE TABLE musicbrainz.l_artist_place (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_artist_place_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_artist_place_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_artist_place_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_artist_place_id_seq OWNED BY musicbrainz.l_artist_place.id;



CREATE TABLE musicbrainz.l_artist_recording (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_artist_recording_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_artist_recording_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_artist_recording_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_artist_recording_id_seq OWNED BY musicbrainz.l_artist_recording.id;



CREATE TABLE musicbrainz.l_artist_release (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_artist_release_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_artist_release_link_order_check CHECK ((link_order >= 0))
);



CREATE TABLE musicbrainz.l_artist_release_group (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_artist_release_group_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_artist_release_group_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_artist_release_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_artist_release_group_id_seq OWNED BY musicbrainz.l_artist_release_group.id;



CREATE SEQUENCE musicbrainz.l_artist_release_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_artist_release_id_seq OWNED BY musicbrainz.l_artist_release.id;



CREATE TABLE musicbrainz.l_artist_series (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_artist_series_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_artist_series_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_artist_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_artist_series_id_seq OWNED BY musicbrainz.l_artist_series.id;



CREATE TABLE musicbrainz.l_artist_url (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_artist_url_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_artist_url_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_artist_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_artist_url_id_seq OWNED BY musicbrainz.l_artist_url.id;



CREATE TABLE musicbrainz.l_artist_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_artist_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_artist_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_artist_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_artist_work_id_seq OWNED BY musicbrainz.l_artist_work.id;



CREATE TABLE musicbrainz.l_event_event (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_event_event_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_event_event_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_event_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_event_event_id_seq OWNED BY musicbrainz.l_event_event.id;



CREATE TABLE musicbrainz.l_event_instrument (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_event_instrument_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_event_instrument_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_event_instrument_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_event_instrument_id_seq OWNED BY musicbrainz.l_event_instrument.id;



CREATE TABLE musicbrainz.l_event_label (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_event_label_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_event_label_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_event_label_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_event_label_id_seq OWNED BY musicbrainz.l_event_label.id;



CREATE TABLE musicbrainz.l_event_place (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_event_place_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_event_place_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_event_place_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_event_place_id_seq OWNED BY musicbrainz.l_event_place.id;



CREATE TABLE musicbrainz.l_event_recording (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_event_recording_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_event_recording_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_event_recording_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_event_recording_id_seq OWNED BY musicbrainz.l_event_recording.id;



CREATE TABLE musicbrainz.l_event_release (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_event_release_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_event_release_link_order_check CHECK ((link_order >= 0))
);



CREATE TABLE musicbrainz.l_event_release_group (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_event_release_group_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_event_release_group_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_event_release_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_event_release_group_id_seq OWNED BY musicbrainz.l_event_release_group.id;



CREATE SEQUENCE musicbrainz.l_event_release_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_event_release_id_seq OWNED BY musicbrainz.l_event_release.id;



CREATE SEQUENCE musicbrainz.l_event_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_event_series_id_seq OWNED BY musicbrainz.l_event_series.id;



CREATE TABLE musicbrainz.l_event_url (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_event_url_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_event_url_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_event_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_event_url_id_seq OWNED BY musicbrainz.l_event_url.id;



CREATE TABLE musicbrainz.l_event_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_event_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_event_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_event_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_event_work_id_seq OWNED BY musicbrainz.l_event_work.id;



CREATE TABLE musicbrainz.l_instrument_instrument (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_instrument_instrument_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_instrument_instrument_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_instrument_instrument_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_instrument_instrument_id_seq OWNED BY musicbrainz.l_instrument_instrument.id;



CREATE TABLE musicbrainz.l_instrument_label (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_instrument_label_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_instrument_label_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_instrument_label_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_instrument_label_id_seq OWNED BY musicbrainz.l_instrument_label.id;



CREATE TABLE musicbrainz.l_instrument_place (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_instrument_place_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_instrument_place_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_instrument_place_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_instrument_place_id_seq OWNED BY musicbrainz.l_instrument_place.id;



CREATE TABLE musicbrainz.l_instrument_recording (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_instrument_recording_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_instrument_recording_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_instrument_recording_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_instrument_recording_id_seq OWNED BY musicbrainz.l_instrument_recording.id;



CREATE TABLE musicbrainz.l_instrument_release (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_instrument_release_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_instrument_release_link_order_check CHECK ((link_order >= 0))
);



CREATE TABLE musicbrainz.l_instrument_release_group (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_instrument_release_group_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_instrument_release_group_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_instrument_release_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_instrument_release_group_id_seq OWNED BY musicbrainz.l_instrument_release_group.id;



CREATE SEQUENCE musicbrainz.l_instrument_release_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_instrument_release_id_seq OWNED BY musicbrainz.l_instrument_release.id;



CREATE TABLE musicbrainz.l_instrument_series (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_instrument_series_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_instrument_series_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_instrument_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_instrument_series_id_seq OWNED BY musicbrainz.l_instrument_series.id;



CREATE TABLE musicbrainz.l_instrument_url (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_instrument_url_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_instrument_url_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_instrument_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_instrument_url_id_seq OWNED BY musicbrainz.l_instrument_url.id;



CREATE TABLE musicbrainz.l_instrument_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_instrument_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_instrument_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_instrument_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_instrument_work_id_seq OWNED BY musicbrainz.l_instrument_work.id;



CREATE TABLE musicbrainz.l_label_label (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_label_label_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_label_label_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_label_label_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_label_label_id_seq OWNED BY musicbrainz.l_label_label.id;



CREATE TABLE musicbrainz.l_label_place (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_label_place_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_label_place_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_label_place_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_label_place_id_seq OWNED BY musicbrainz.l_label_place.id;



CREATE TABLE musicbrainz.l_label_recording (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_label_recording_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_label_recording_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_label_recording_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_label_recording_id_seq OWNED BY musicbrainz.l_label_recording.id;



CREATE TABLE musicbrainz.l_label_release (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_label_release_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_label_release_link_order_check CHECK ((link_order >= 0))
);



CREATE TABLE musicbrainz.l_label_release_group (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_label_release_group_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_label_release_group_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_label_release_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_label_release_group_id_seq OWNED BY musicbrainz.l_label_release_group.id;



CREATE SEQUENCE musicbrainz.l_label_release_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_label_release_id_seq OWNED BY musicbrainz.l_label_release.id;



CREATE TABLE musicbrainz.l_label_series (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_label_series_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_label_series_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_label_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_label_series_id_seq OWNED BY musicbrainz.l_label_series.id;



CREATE TABLE musicbrainz.l_label_url (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_label_url_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_label_url_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_label_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_label_url_id_seq OWNED BY musicbrainz.l_label_url.id;



CREATE TABLE musicbrainz.l_label_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_label_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_label_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_label_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_label_work_id_seq OWNED BY musicbrainz.l_label_work.id;



CREATE TABLE musicbrainz.l_place_place (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_place_place_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_place_place_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_place_place_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_place_place_id_seq OWNED BY musicbrainz.l_place_place.id;



CREATE TABLE musicbrainz.l_place_recording (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_place_recording_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_place_recording_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_place_recording_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_place_recording_id_seq OWNED BY musicbrainz.l_place_recording.id;



CREATE TABLE musicbrainz.l_place_release (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_place_release_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_place_release_link_order_check CHECK ((link_order >= 0))
);



CREATE TABLE musicbrainz.l_place_release_group (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_place_release_group_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_place_release_group_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_place_release_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_place_release_group_id_seq OWNED BY musicbrainz.l_place_release_group.id;



CREATE SEQUENCE musicbrainz.l_place_release_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_place_release_id_seq OWNED BY musicbrainz.l_place_release.id;



CREATE TABLE musicbrainz.l_place_series (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_place_series_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_place_series_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_place_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_place_series_id_seq OWNED BY musicbrainz.l_place_series.id;



CREATE TABLE musicbrainz.l_place_url (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_place_url_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_place_url_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_place_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_place_url_id_seq OWNED BY musicbrainz.l_place_url.id;



CREATE TABLE musicbrainz.l_place_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_place_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_place_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_place_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_place_work_id_seq OWNED BY musicbrainz.l_place_work.id;



CREATE TABLE musicbrainz.l_recording_recording (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_recording_recording_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_recording_recording_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_recording_recording_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_recording_recording_id_seq OWNED BY musicbrainz.l_recording_recording.id;



CREATE TABLE musicbrainz.l_recording_release (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_recording_release_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_recording_release_link_order_check CHECK ((link_order >= 0))
);



CREATE TABLE musicbrainz.l_recording_release_group (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_recording_release_group_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_recording_release_group_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_recording_release_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_recording_release_group_id_seq OWNED BY musicbrainz.l_recording_release_group.id;



CREATE SEQUENCE musicbrainz.l_recording_release_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_recording_release_id_seq OWNED BY musicbrainz.l_recording_release.id;



CREATE TABLE musicbrainz.l_recording_series (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_recording_series_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_recording_series_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_recording_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_recording_series_id_seq OWNED BY musicbrainz.l_recording_series.id;



CREATE TABLE musicbrainz.l_recording_url (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_recording_url_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_recording_url_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_recording_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_recording_url_id_seq OWNED BY musicbrainz.l_recording_url.id;



CREATE TABLE musicbrainz.l_recording_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_recording_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_recording_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_recording_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_recording_work_id_seq OWNED BY musicbrainz.l_recording_work.id;



CREATE TABLE musicbrainz.l_release_group_release_group (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_release_group_release_group_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_release_group_release_group_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_release_group_release_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_release_group_release_group_id_seq OWNED BY musicbrainz.l_release_group_release_group.id;



CREATE TABLE musicbrainz.l_release_group_series (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_release_group_series_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_release_group_series_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_release_group_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_release_group_series_id_seq OWNED BY musicbrainz.l_release_group_series.id;



CREATE TABLE musicbrainz.l_release_group_url (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_release_group_url_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_release_group_url_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_release_group_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_release_group_url_id_seq OWNED BY musicbrainz.l_release_group_url.id;



CREATE TABLE musicbrainz.l_release_group_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_release_group_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_release_group_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_release_group_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_release_group_work_id_seq OWNED BY musicbrainz.l_release_group_work.id;



CREATE TABLE musicbrainz.l_release_release (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_release_release_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_release_release_link_order_check CHECK ((link_order >= 0))
);



CREATE TABLE musicbrainz.l_release_release_group (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_release_release_group_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_release_release_group_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_release_release_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_release_release_group_id_seq OWNED BY musicbrainz.l_release_release_group.id;



CREATE SEQUENCE musicbrainz.l_release_release_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_release_release_id_seq OWNED BY musicbrainz.l_release_release.id;



CREATE TABLE musicbrainz.l_release_series (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_release_series_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_release_series_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_release_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_release_series_id_seq OWNED BY musicbrainz.l_release_series.id;



CREATE TABLE musicbrainz.l_release_url (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_release_url_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_release_url_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_release_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_release_url_id_seq OWNED BY musicbrainz.l_release_url.id;



CREATE TABLE musicbrainz.l_release_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_release_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_release_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_release_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_release_work_id_seq OWNED BY musicbrainz.l_release_work.id;



CREATE TABLE musicbrainz.l_series_series (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_series_series_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_series_series_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_series_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_series_series_id_seq OWNED BY musicbrainz.l_series_series.id;



CREATE TABLE musicbrainz.l_series_url (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_series_url_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_series_url_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_series_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_series_url_id_seq OWNED BY musicbrainz.l_series_url.id;



CREATE TABLE musicbrainz.l_series_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_series_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_series_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_series_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_series_work_id_seq OWNED BY musicbrainz.l_series_work.id;



CREATE TABLE musicbrainz.l_url_url (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_url_url_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_url_url_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_url_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_url_url_id_seq OWNED BY musicbrainz.l_url_url.id;



CREATE TABLE musicbrainz.l_url_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_url_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_url_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_url_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_url_work_id_seq OWNED BY musicbrainz.l_url_work.id;



CREATE TABLE musicbrainz.l_work_work (
    id integer NOT NULL,
    link integer NOT NULL,
    entity0 integer NOT NULL,
    entity1 integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    link_order integer DEFAULT 0 NOT NULL,
    entity0_credit text DEFAULT ''::text NOT NULL,
    entity1_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT l_work_work_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT l_work_work_link_order_check CHECK ((link_order >= 0))
);



CREATE SEQUENCE musicbrainz.l_work_work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.l_work_work_id_seq OWNED BY musicbrainz.l_work_work.id;



CREATE TABLE musicbrainz.label (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    label_code integer,
    type integer,
    area integer,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT label_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT label_ended_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT label_label_code_check CHECK (((label_code > 0) AND (label_code < 100000)))
);



CREATE TABLE musicbrainz.label_alias (
    id integer NOT NULL,
    label integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    type integer,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    primary_for_locale boolean DEFAULT false NOT NULL,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT label_alias_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT label_alias_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL))),
    CONSTRAINT search_hints_are_empty CHECK (((type <> 2) OR ((type = 2) AND ((sort_name)::text = (name)::text) AND (begin_date_year IS NULL) AND (begin_date_month IS NULL) AND (begin_date_day IS NULL) AND (end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL) AND (primary_for_locale IS FALSE) AND (locale IS NULL))))
);



CREATE SEQUENCE musicbrainz.label_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.label_alias_id_seq OWNED BY musicbrainz.label_alias.id;



CREATE TABLE musicbrainz.label_alias_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.label_alias_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.label_alias_type_id_seq OWNED BY musicbrainz.label_alias_type.id;



CREATE TABLE musicbrainz.label_annotation (
    label integer NOT NULL,
    annotation integer NOT NULL
);



CREATE TABLE musicbrainz.label_attribute (
    id integer NOT NULL,
    label integer NOT NULL,
    label_attribute_type integer NOT NULL,
    label_attribute_type_allowed_value integer,
    label_attribute_text text,
    CONSTRAINT label_attribute_check CHECK ((((label_attribute_type_allowed_value IS NULL) AND (label_attribute_text IS NOT NULL)) OR ((label_attribute_type_allowed_value IS NOT NULL) AND (label_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.label_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.label_attribute_id_seq OWNED BY musicbrainz.label_attribute.id;



CREATE TABLE musicbrainz.label_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.label_attribute_type_allowed_value (
    id integer NOT NULL,
    label_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.label_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.label_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.label_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.label_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.label_attribute_type_id_seq OWNED BY musicbrainz.label_attribute_type.id;



CREATE TABLE musicbrainz.label_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.label_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.label_id_seq OWNED BY musicbrainz.label.id;



CREATE TABLE musicbrainz.label_ipi (
    label integer NOT NULL,
    ipi character(11) NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    created timestamp with time zone DEFAULT now(),
    CONSTRAINT label_ipi_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT label_ipi_ipi_check CHECK ((ipi ~ '^\d{11}$'::text))
);



CREATE TABLE musicbrainz.label_isni (
    label integer NOT NULL,
    isni character(16) NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    created timestamp with time zone DEFAULT now(),
    CONSTRAINT label_isni_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT label_isni_isni_check CHECK ((isni ~ '^\d{15}[\dX]$'::text))
);



CREATE TABLE musicbrainz.label_meta (
    id integer NOT NULL,
    rating smallint,
    rating_count integer,
    CONSTRAINT label_meta_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE TABLE musicbrainz.label_rating_raw (
    label integer NOT NULL,
    editor integer NOT NULL,
    rating smallint NOT NULL,
    CONSTRAINT label_rating_raw_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE TABLE musicbrainz.label_tag (
    label integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.label_tag_raw (
    label integer NOT NULL,
    editor integer NOT NULL,
    tag integer NOT NULL,
    is_upvote boolean DEFAULT true NOT NULL
);



CREATE TABLE musicbrainz.label_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.label_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.label_type_id_seq OWNED BY musicbrainz.label_type.id;



CREATE TABLE musicbrainz.language (
    id integer NOT NULL,
    iso_code_2t character(3),
    iso_code_2b character(3),
    iso_code_1 character(2),
    name character varying(100) NOT NULL,
    frequency integer DEFAULT 0 NOT NULL,
    iso_code_3 character(3),
    CONSTRAINT iso_code_check CHECK (((iso_code_2t IS NOT NULL) OR (iso_code_3 IS NOT NULL)))
);



CREATE SEQUENCE musicbrainz.language_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.language_id_seq OWNED BY musicbrainz.language.id;



CREATE TABLE musicbrainz.link_attribute (
    link integer NOT NULL,
    attribute_type integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.link_attribute_credit (
    link integer NOT NULL,
    attribute_type integer NOT NULL,
    credited_as text NOT NULL
);



CREATE TABLE musicbrainz.link_attribute_type (
    id integer NOT NULL,
    parent integer,
    root integer NOT NULL,
    child_order integer DEFAULT 0 NOT NULL,
    gid uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.link_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.link_attribute_type_id_seq OWNED BY musicbrainz.link_attribute_type.id;



CREATE TABLE musicbrainz.link_creditable_attribute_type (
    attribute_type integer NOT NULL
);



CREATE SEQUENCE musicbrainz.link_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.link_id_seq OWNED BY musicbrainz.link.id;



CREATE TABLE musicbrainz.link_text_attribute_type (
    attribute_type integer NOT NULL
);



CREATE TABLE musicbrainz.link_type_attribute_type (
    link_type integer NOT NULL,
    attribute_type integer NOT NULL,
    min smallint,
    max smallint,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.link_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.link_type_id_seq OWNED BY musicbrainz.link_type.id;



CREATE TABLE musicbrainz.medium_attribute (
    id integer NOT NULL,
    medium integer NOT NULL,
    medium_attribute_type integer NOT NULL,
    medium_attribute_type_allowed_value integer,
    medium_attribute_text text,
    CONSTRAINT medium_attribute_check CHECK ((((medium_attribute_type_allowed_value IS NULL) AND (medium_attribute_text IS NOT NULL)) OR ((medium_attribute_type_allowed_value IS NOT NULL) AND (medium_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.medium_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.medium_attribute_id_seq OWNED BY musicbrainz.medium_attribute.id;



CREATE TABLE musicbrainz.medium_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.medium_attribute_type_allowed_format (
    medium_format integer NOT NULL,
    medium_attribute_type integer NOT NULL
);



CREATE TABLE musicbrainz.medium_attribute_type_allowed_value (
    id integer NOT NULL,
    medium_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.medium_attribute_type_allowed_value_allowed_format (
    medium_format integer NOT NULL,
    medium_attribute_type_allowed_value integer NOT NULL
);



CREATE SEQUENCE musicbrainz.medium_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.medium_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.medium_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.medium_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.medium_attribute_type_id_seq OWNED BY musicbrainz.medium_attribute_type.id;



CREATE TABLE musicbrainz.medium_cdtoc (
    id integer NOT NULL,
    medium integer NOT NULL,
    cdtoc integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    CONSTRAINT medium_cdtoc_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE SEQUENCE musicbrainz.medium_cdtoc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.medium_cdtoc_id_seq OWNED BY musicbrainz.medium_cdtoc.id;



CREATE TABLE musicbrainz.medium_format (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    year smallint,
    has_discids boolean DEFAULT false NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.medium_format_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.medium_format_id_seq OWNED BY musicbrainz.medium_format.id;



CREATE SEQUENCE musicbrainz.medium_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.medium_id_seq OWNED BY musicbrainz.medium.id;



CREATE TABLE musicbrainz.medium_index (
    medium integer NOT NULL,
    toc public.cube
);



CREATE TABLE musicbrainz.old_editor_name (
    name character varying(64) NOT NULL
);



CREATE TABLE musicbrainz.orderable_link_type (
    link_type integer NOT NULL,
    direction smallint DEFAULT 1 NOT NULL,
    CONSTRAINT orderable_link_type_direction_check CHECK (((direction = 1) OR (direction = 2)))
);



CREATE TABLE musicbrainz.place (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    type integer,
    address character varying DEFAULT ''::character varying NOT NULL,
    area integer,
    coordinates point,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT place_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT place_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE TABLE musicbrainz.place_alias (
    id integer NOT NULL,
    place integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    type integer,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    primary_for_locale boolean DEFAULT false NOT NULL,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT place_alias_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT place_alias_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL))),
    CONSTRAINT search_hints_are_empty CHECK (((type <> 2) OR ((type = 2) AND ((sort_name)::text = (name)::text) AND (begin_date_year IS NULL) AND (begin_date_month IS NULL) AND (begin_date_day IS NULL) AND (end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL) AND (primary_for_locale IS FALSE) AND (locale IS NULL))))
);



CREATE SEQUENCE musicbrainz.place_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.place_alias_id_seq OWNED BY musicbrainz.place_alias.id;



CREATE TABLE musicbrainz.place_alias_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.place_alias_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.place_alias_type_id_seq OWNED BY musicbrainz.place_alias_type.id;



CREATE TABLE musicbrainz.place_annotation (
    place integer NOT NULL,
    annotation integer NOT NULL
);



CREATE TABLE musicbrainz.place_attribute (
    id integer NOT NULL,
    place integer NOT NULL,
    place_attribute_type integer NOT NULL,
    place_attribute_type_allowed_value integer,
    place_attribute_text text,
    CONSTRAINT place_attribute_check CHECK ((((place_attribute_type_allowed_value IS NULL) AND (place_attribute_text IS NOT NULL)) OR ((place_attribute_type_allowed_value IS NOT NULL) AND (place_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.place_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.place_attribute_id_seq OWNED BY musicbrainz.place_attribute.id;



CREATE TABLE musicbrainz.place_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.place_attribute_type_allowed_value (
    id integer NOT NULL,
    place_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.place_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.place_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.place_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.place_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.place_attribute_type_id_seq OWNED BY musicbrainz.place_attribute_type.id;



CREATE TABLE musicbrainz.place_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.place_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.place_id_seq OWNED BY musicbrainz.place.id;



CREATE TABLE musicbrainz.place_tag (
    place integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.place_tag_raw (
    place integer NOT NULL,
    editor integer NOT NULL,
    tag integer NOT NULL,
    is_upvote boolean DEFAULT true NOT NULL
);



CREATE TABLE musicbrainz.place_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.place_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.place_type_id_seq OWNED BY musicbrainz.place_type.id;



CREATE TABLE musicbrainz.recording (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    artist_credit integer NOT NULL,
    length integer,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    video boolean DEFAULT false NOT NULL,
    CONSTRAINT recording_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT recording_length_check CHECK (((length IS NULL) OR (length > 0)))
);



CREATE TABLE musicbrainz.recording_alias (
    id integer NOT NULL,
    recording integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    type integer,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    primary_for_locale boolean DEFAULT false NOT NULL,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL))),
    CONSTRAINT recording_alias_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT recording_alias_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE SEQUENCE musicbrainz.recording_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.recording_alias_id_seq OWNED BY musicbrainz.recording_alias.id;



CREATE TABLE musicbrainz.recording_alias_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.recording_alias_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.recording_alias_type_id_seq OWNED BY musicbrainz.recording_alias_type.id;



CREATE TABLE musicbrainz.recording_annotation (
    recording integer NOT NULL,
    annotation integer NOT NULL
);



CREATE TABLE musicbrainz.recording_attribute (
    id integer NOT NULL,
    recording integer NOT NULL,
    recording_attribute_type integer NOT NULL,
    recording_attribute_type_allowed_value integer,
    recording_attribute_text text,
    CONSTRAINT recording_attribute_check CHECK ((((recording_attribute_type_allowed_value IS NULL) AND (recording_attribute_text IS NOT NULL)) OR ((recording_attribute_type_allowed_value IS NOT NULL) AND (recording_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.recording_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.recording_attribute_id_seq OWNED BY musicbrainz.recording_attribute.id;



CREATE TABLE musicbrainz.recording_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.recording_attribute_type_allowed_value (
    id integer NOT NULL,
    recording_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.recording_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.recording_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.recording_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.recording_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.recording_attribute_type_id_seq OWNED BY musicbrainz.recording_attribute_type.id;



CREATE TABLE musicbrainz.recording_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.recording_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.recording_id_seq OWNED BY musicbrainz.recording.id;



CREATE TABLE musicbrainz.recording_meta (
    id integer NOT NULL,
    rating smallint,
    rating_count integer,
    CONSTRAINT recording_meta_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE TABLE musicbrainz.recording_rating_raw (
    recording integer NOT NULL,
    editor integer NOT NULL,
    rating smallint NOT NULL,
    CONSTRAINT recording_rating_raw_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE VIEW musicbrainz.recording_series AS
 SELECT lrs.entity0 AS recording,
    lrs.entity1 AS series,
    lrs.id AS relationship,
    lrs.link_order,
    lrs.link,
    COALESCE(latv.text_value, ''::text) AS text_value
   FROM ((((musicbrainz.l_recording_series lrs
     JOIN musicbrainz.series s ON ((s.id = lrs.entity1)))
     JOIN musicbrainz.link l ON ((l.id = lrs.link)))
     JOIN musicbrainz.link_type lt ON (((lt.id = l.link_type) AND (lt.gid = 'ea6f0698-6782-30d6-b16d-293081b66774'::uuid))))
     LEFT JOIN musicbrainz.link_attribute_text_value latv ON (((latv.attribute_type = s.ordering_attribute) AND (latv.link = l.id))))
  ORDER BY lrs.entity1, lrs.link_order;



CREATE TABLE musicbrainz.recording_tag (
    recording integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.recording_tag_raw (
    recording integer NOT NULL,
    editor integer NOT NULL,
    tag integer NOT NULL,
    is_upvote boolean DEFAULT true NOT NULL
);



CREATE TABLE musicbrainz.release (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    artist_credit integer NOT NULL,
    release_group integer NOT NULL,
    status integer,
    packaging integer,
    language integer,
    script integer,
    barcode character varying(255),
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    quality smallint DEFAULT '-1'::integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    CONSTRAINT release_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE TABLE musicbrainz.release_alias (
    id integer NOT NULL,
    release integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    type integer,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    primary_for_locale boolean DEFAULT false NOT NULL,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL))),
    CONSTRAINT release_alias_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT release_alias_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE SEQUENCE musicbrainz.release_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_alias_id_seq OWNED BY musicbrainz.release_alias.id;



CREATE TABLE musicbrainz.release_alias_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.release_alias_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_alias_type_id_seq OWNED BY musicbrainz.release_alias_type.id;



CREATE TABLE musicbrainz.release_annotation (
    release integer NOT NULL,
    annotation integer NOT NULL
);



CREATE TABLE musicbrainz.release_attribute (
    id integer NOT NULL,
    release integer NOT NULL,
    release_attribute_type integer NOT NULL,
    release_attribute_type_allowed_value integer,
    release_attribute_text text,
    CONSTRAINT release_attribute_check CHECK ((((release_attribute_type_allowed_value IS NULL) AND (release_attribute_text IS NOT NULL)) OR ((release_attribute_type_allowed_value IS NOT NULL) AND (release_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.release_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_attribute_id_seq OWNED BY musicbrainz.release_attribute.id;



CREATE TABLE musicbrainz.release_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.release_attribute_type_allowed_value (
    id integer NOT NULL,
    release_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.release_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.release_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.release_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_attribute_type_id_seq OWNED BY musicbrainz.release_attribute_type.id;



CREATE TABLE musicbrainz.release_country (
    release integer NOT NULL,
    country integer NOT NULL,
    date_year smallint,
    date_month smallint,
    date_day smallint
);



CREATE TABLE musicbrainz.release_coverart (
    id integer NOT NULL,
    last_updated timestamp with time zone,
    cover_art_url character varying(255)
);



CREATE TABLE musicbrainz.release_unknown_country (
    release integer NOT NULL,
    date_year smallint,
    date_month smallint,
    date_day smallint
);



CREATE VIEW musicbrainz.release_event AS
 SELECT q.release,
    q.date_year,
    q.date_month,
    q.date_day,
    q.country
   FROM ( SELECT release_country.release,
            release_country.date_year,
            release_country.date_month,
            release_country.date_day,
            release_country.country
           FROM musicbrainz.release_country
        UNION ALL
         SELECT release_unknown_country.release,
            release_unknown_country.date_year,
            release_unknown_country.date_month,
            release_unknown_country.date_day,
            NULL::integer
           FROM musicbrainz.release_unknown_country) q;



CREATE TABLE musicbrainz.release_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.release_group (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    artist_credit integer NOT NULL,
    type integer,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    CONSTRAINT release_group_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE TABLE musicbrainz.release_group_alias (
    id integer NOT NULL,
    release_group integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    type integer,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    primary_for_locale boolean DEFAULT false NOT NULL,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL))),
    CONSTRAINT release_group_alias_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT release_group_alias_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE SEQUENCE musicbrainz.release_group_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_group_alias_id_seq OWNED BY musicbrainz.release_group_alias.id;



CREATE TABLE musicbrainz.release_group_alias_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.release_group_alias_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_group_alias_type_id_seq OWNED BY musicbrainz.release_group_alias_type.id;



CREATE TABLE musicbrainz.release_group_annotation (
    release_group integer NOT NULL,
    annotation integer NOT NULL
);



CREATE TABLE musicbrainz.release_group_attribute (
    id integer NOT NULL,
    release_group integer NOT NULL,
    release_group_attribute_type integer NOT NULL,
    release_group_attribute_type_allowed_value integer,
    release_group_attribute_text text,
    CONSTRAINT release_group_attribute_check CHECK ((((release_group_attribute_type_allowed_value IS NULL) AND (release_group_attribute_text IS NOT NULL)) OR ((release_group_attribute_type_allowed_value IS NOT NULL) AND (release_group_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.release_group_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_group_attribute_id_seq OWNED BY musicbrainz.release_group_attribute.id;



CREATE TABLE musicbrainz.release_group_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.release_group_attribute_type_allowed_value (
    id integer NOT NULL,
    release_group_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.release_group_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_group_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.release_group_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.release_group_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_group_attribute_type_id_seq OWNED BY musicbrainz.release_group_attribute_type.id;



CREATE TABLE musicbrainz.release_group_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.release_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_group_id_seq OWNED BY musicbrainz.release_group.id;



CREATE TABLE musicbrainz.release_group_meta (
    id integer NOT NULL,
    release_count integer DEFAULT 0 NOT NULL,
    first_release_date_year smallint,
    first_release_date_month smallint,
    first_release_date_day smallint,
    rating smallint,
    rating_count integer,
    CONSTRAINT release_group_meta_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE TABLE musicbrainz.release_group_primary_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.release_group_primary_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_group_primary_type_id_seq OWNED BY musicbrainz.release_group_primary_type.id;



CREATE TABLE musicbrainz.release_group_rating_raw (
    release_group integer NOT NULL,
    editor integer NOT NULL,
    rating smallint NOT NULL,
    CONSTRAINT release_group_rating_raw_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE TABLE musicbrainz.release_group_secondary_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.release_group_secondary_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_group_secondary_type_id_seq OWNED BY musicbrainz.release_group_secondary_type.id;



CREATE TABLE musicbrainz.release_group_secondary_type_join (
    release_group integer NOT NULL,
    secondary_type integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);



CREATE VIEW musicbrainz.release_group_series AS
 SELECT lrgs.entity0 AS release_group,
    lrgs.entity1 AS series,
    lrgs.id AS relationship,
    lrgs.link_order,
    lrgs.link,
    COALESCE(latv.text_value, ''::text) AS text_value
   FROM ((((musicbrainz.l_release_group_series lrgs
     JOIN musicbrainz.series s ON ((s.id = lrgs.entity1)))
     JOIN musicbrainz.link l ON ((l.id = lrgs.link)))
     JOIN musicbrainz.link_type lt ON (((lt.id = l.link_type) AND (lt.gid = '01018437-91d8-36b9-bf89-3f885d53b5bd'::uuid))))
     LEFT JOIN musicbrainz.link_attribute_text_value latv ON (((latv.attribute_type = s.ordering_attribute) AND (latv.link = l.id))))
  ORDER BY lrgs.entity1, lrgs.link_order;



CREATE TABLE musicbrainz.release_group_tag (
    release_group integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.release_group_tag_raw (
    release_group integer NOT NULL,
    editor integer NOT NULL,
    tag integer NOT NULL,
    is_upvote boolean DEFAULT true NOT NULL
);



CREATE SEQUENCE musicbrainz.release_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_id_seq OWNED BY musicbrainz.release.id;



CREATE TABLE musicbrainz.release_label (
    id integer NOT NULL,
    release integer NOT NULL,
    label integer,
    catalog_number character varying(255),
    last_updated timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.release_label_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_label_id_seq OWNED BY musicbrainz.release_label.id;



CREATE TABLE musicbrainz.release_meta (
    id integer NOT NULL,
    date_added timestamp with time zone DEFAULT now(),
    info_url character varying(255),
    amazon_asin character varying(10),
    amazon_store character varying(20),
    cover_art_presence musicbrainz.cover_art_presence DEFAULT 'absent'::musicbrainz.cover_art_presence NOT NULL
);



CREATE TABLE musicbrainz.release_packaging (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.release_packaging_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_packaging_id_seq OWNED BY musicbrainz.release_packaging.id;



CREATE TABLE musicbrainz.release_raw (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    artist character varying(255),
    added timestamp with time zone DEFAULT now(),
    last_modified timestamp with time zone DEFAULT now(),
    lookup_count integer DEFAULT 0,
    modify_count integer DEFAULT 0,
    source integer DEFAULT 0,
    barcode character varying(255),
    comment character varying(255) DEFAULT ''::character varying NOT NULL
);



CREATE SEQUENCE musicbrainz.release_raw_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_raw_id_seq OWNED BY musicbrainz.release_raw.id;



CREATE VIEW musicbrainz.release_series AS
 SELECT lrs.entity0 AS release,
    lrs.entity1 AS series,
    lrs.id AS relationship,
    lrs.link_order,
    lrs.link,
    COALESCE(latv.text_value, ''::text) AS text_value
   FROM ((((musicbrainz.l_release_series lrs
     JOIN musicbrainz.series s ON ((s.id = lrs.entity1)))
     JOIN musicbrainz.link l ON ((l.id = lrs.link)))
     JOIN musicbrainz.link_type lt ON (((lt.id = l.link_type) AND (lt.gid = '3fa29f01-8e13-3e49-9b0a-ad212aa2f81d'::uuid))))
     LEFT JOIN musicbrainz.link_attribute_text_value latv ON (((latv.attribute_type = s.ordering_attribute) AND (latv.link = l.id))))
  ORDER BY lrs.entity1, lrs.link_order;



CREATE TABLE musicbrainz.release_status (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.release_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.release_status_id_seq OWNED BY musicbrainz.release_status.id;



CREATE TABLE musicbrainz.release_tag (
    release integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.release_tag_raw (
    release integer NOT NULL,
    editor integer NOT NULL,
    tag integer NOT NULL,
    is_upvote boolean DEFAULT true NOT NULL
);



CREATE TABLE musicbrainz.replication_control (
    id integer NOT NULL,
    current_schema_sequence integer NOT NULL,
    current_replication_sequence integer,
    last_replication_date timestamp with time zone
);



CREATE SEQUENCE musicbrainz.replication_control_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.replication_control_id_seq OWNED BY musicbrainz.replication_control.id;



CREATE TABLE musicbrainz.script (
    id integer NOT NULL,
    iso_code character(4) NOT NULL,
    iso_number character(3) NOT NULL,
    name character varying(100) NOT NULL,
    frequency integer DEFAULT 0 NOT NULL
);



CREATE SEQUENCE musicbrainz.script_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.script_id_seq OWNED BY musicbrainz.script.id;



CREATE TABLE musicbrainz.series_alias (
    id integer NOT NULL,
    series integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    type integer,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    primary_for_locale boolean DEFAULT false NOT NULL,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL))),
    CONSTRAINT search_hints_are_empty CHECK (((type <> 2) OR ((type = 2) AND ((sort_name)::text = (name)::text) AND (begin_date_year IS NULL) AND (begin_date_month IS NULL) AND (begin_date_day IS NULL) AND (end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL) AND (primary_for_locale IS FALSE) AND (locale IS NULL)))),
    CONSTRAINT series_alias_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT series_alias_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE SEQUENCE musicbrainz.series_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.series_alias_id_seq OWNED BY musicbrainz.series_alias.id;



CREATE TABLE musicbrainz.series_alias_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.series_alias_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.series_alias_type_id_seq OWNED BY musicbrainz.series_alias_type.id;



CREATE TABLE musicbrainz.series_annotation (
    series integer NOT NULL,
    annotation integer NOT NULL
);



CREATE TABLE musicbrainz.series_attribute (
    id integer NOT NULL,
    series integer NOT NULL,
    series_attribute_type integer NOT NULL,
    series_attribute_type_allowed_value integer,
    series_attribute_text text,
    CONSTRAINT series_attribute_check CHECK ((((series_attribute_type_allowed_value IS NULL) AND (series_attribute_text IS NOT NULL)) OR ((series_attribute_type_allowed_value IS NOT NULL) AND (series_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.series_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.series_attribute_id_seq OWNED BY musicbrainz.series_attribute.id;



CREATE TABLE musicbrainz.series_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.series_attribute_type_allowed_value (
    id integer NOT NULL,
    series_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.series_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.series_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.series_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.series_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.series_attribute_type_id_seq OWNED BY musicbrainz.series_attribute_type.id;



CREATE TABLE musicbrainz.series_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.series_id_seq OWNED BY musicbrainz.series.id;



CREATE TABLE musicbrainz.series_ordering_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.series_ordering_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.series_ordering_type_id_seq OWNED BY musicbrainz.series_ordering_type.id;



CREATE TABLE musicbrainz.series_tag (
    series integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.series_tag_raw (
    series integer NOT NULL,
    editor integer NOT NULL,
    tag integer NOT NULL,
    is_upvote boolean DEFAULT true NOT NULL
);



CREATE TABLE musicbrainz.series_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    entity_type character varying(50) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.series_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.series_type_id_seq OWNED BY musicbrainz.series_type.id;



CREATE TABLE musicbrainz.tag (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    ref_count integer DEFAULT 0 NOT NULL
);



CREATE SEQUENCE musicbrainz.tag_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.tag_id_seq OWNED BY musicbrainz.tag.id;



CREATE TABLE musicbrainz.tag_relation (
    tag1 integer NOT NULL,
    tag2 integer NOT NULL,
    weight integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    CONSTRAINT tag_relation_check CHECK ((tag1 < tag2))
);



CREATE TABLE musicbrainz.track (
    id integer NOT NULL,
    gid uuid NOT NULL,
    recording integer NOT NULL,
    medium integer NOT NULL,
    "position" integer NOT NULL,
    number text NOT NULL,
    name character varying NOT NULL,
    artist_credit integer NOT NULL,
    length integer,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    is_data_track boolean DEFAULT false NOT NULL,
    CONSTRAINT track_edits_pending_check CHECK ((edits_pending >= 0)),
    CONSTRAINT track_length_check CHECK (((length IS NULL) OR (length > 0)))
);



CREATE TABLE musicbrainz.track_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.track_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.track_id_seq OWNED BY musicbrainz.track.id;



CREATE TABLE musicbrainz.track_raw (
    id integer NOT NULL,
    release integer NOT NULL,
    title character varying(255) NOT NULL,
    artist character varying(255),
    sequence integer NOT NULL
);



CREATE SEQUENCE musicbrainz.track_raw_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.track_raw_id_seq OWNED BY musicbrainz.track_raw.id;



CREATE TABLE musicbrainz.url (
    id integer NOT NULL,
    gid uuid NOT NULL,
    url text NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    CONSTRAINT url_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE TABLE musicbrainz.url_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.url_id_seq OWNED BY musicbrainz.url.id;



CREATE TABLE musicbrainz.vote (
    id integer NOT NULL,
    editor integer NOT NULL,
    edit integer NOT NULL,
    vote smallint NOT NULL,
    vote_time timestamp with time zone DEFAULT now(),
    superseded boolean DEFAULT false NOT NULL
);



CREATE SEQUENCE musicbrainz.vote_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.vote_id_seq OWNED BY musicbrainz.vote.id;



CREATE TABLE musicbrainz.work (
    id integer NOT NULL,
    gid uuid NOT NULL,
    name character varying NOT NULL,
    type integer,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    CONSTRAINT work_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE TABLE musicbrainz.work_alias (
    id integer NOT NULL,
    work integer NOT NULL,
    name character varying NOT NULL,
    locale text,
    edits_pending integer DEFAULT 0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now(),
    type integer,
    sort_name character varying NOT NULL,
    begin_date_year smallint,
    begin_date_month smallint,
    begin_date_day smallint,
    end_date_year smallint,
    end_date_month smallint,
    end_date_day smallint,
    primary_for_locale boolean DEFAULT false NOT NULL,
    ended boolean DEFAULT false NOT NULL,
    CONSTRAINT primary_check CHECK ((((locale IS NULL) AND (primary_for_locale IS FALSE)) OR (locale IS NOT NULL))),
    CONSTRAINT search_hints_are_empty CHECK (((type <> 2) OR ((type = 2) AND ((sort_name)::text = (name)::text) AND (begin_date_year IS NULL) AND (begin_date_month IS NULL) AND (begin_date_day IS NULL) AND (end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL) AND (primary_for_locale IS FALSE) AND (locale IS NULL)))),
    CONSTRAINT work_alias_check CHECK (((((end_date_year IS NOT NULL) OR (end_date_month IS NOT NULL) OR (end_date_day IS NOT NULL)) AND (ended = true)) OR ((end_date_year IS NULL) AND (end_date_month IS NULL) AND (end_date_day IS NULL)))),
    CONSTRAINT work_alias_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE SEQUENCE musicbrainz.work_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.work_alias_id_seq OWNED BY musicbrainz.work_alias.id;



CREATE TABLE musicbrainz.work_alias_type (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.work_alias_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.work_alias_type_id_seq OWNED BY musicbrainz.work_alias_type.id;



CREATE TABLE musicbrainz.work_annotation (
    work integer NOT NULL,
    annotation integer NOT NULL
);



CREATE TABLE musicbrainz.work_attribute (
    id integer NOT NULL,
    work integer NOT NULL,
    work_attribute_type integer NOT NULL,
    work_attribute_type_allowed_value integer,
    work_attribute_text text,
    CONSTRAINT work_attribute_check CHECK ((((work_attribute_type_allowed_value IS NULL) AND (work_attribute_text IS NOT NULL)) OR ((work_attribute_type_allowed_value IS NOT NULL) AND (work_attribute_text IS NULL))))
);



CREATE SEQUENCE musicbrainz.work_attribute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.work_attribute_id_seq OWNED BY musicbrainz.work_attribute.id;



CREATE TABLE musicbrainz.work_attribute_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    comment character varying(255) DEFAULT ''::character varying NOT NULL,
    free_text boolean NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE TABLE musicbrainz.work_attribute_type_allowed_value (
    id integer NOT NULL,
    work_attribute_type integer NOT NULL,
    value text,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.work_attribute_type_allowed_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.work_attribute_type_allowed_value_id_seq OWNED BY musicbrainz.work_attribute_type_allowed_value.id;



CREATE SEQUENCE musicbrainz.work_attribute_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.work_attribute_type_id_seq OWNED BY musicbrainz.work_attribute_type.id;



CREATE TABLE musicbrainz.work_gid_redirect (
    gid uuid NOT NULL,
    new_id integer NOT NULL,
    created timestamp with time zone DEFAULT now()
);



CREATE SEQUENCE musicbrainz.work_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.work_id_seq OWNED BY musicbrainz.work.id;



CREATE TABLE musicbrainz.work_language (
    work integer NOT NULL,
    language integer NOT NULL,
    edits_pending integer DEFAULT 0 NOT NULL,
    created timestamp with time zone DEFAULT now(),
    CONSTRAINT work_language_edits_pending_check CHECK ((edits_pending >= 0))
);



CREATE TABLE musicbrainz.work_meta (
    id integer NOT NULL,
    rating smallint,
    rating_count integer,
    CONSTRAINT work_meta_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE TABLE musicbrainz.work_rating_raw (
    work integer NOT NULL,
    editor integer NOT NULL,
    rating smallint NOT NULL,
    CONSTRAINT work_rating_raw_rating_check CHECK (((rating >= 0) AND (rating <= 100)))
);



CREATE VIEW musicbrainz.work_series AS
 SELECT lsw.entity1 AS work,
    lsw.entity0 AS series,
    lsw.id AS relationship,
    lsw.link_order,
    lsw.link,
    COALESCE(latv.text_value, ''::text) AS text_value
   FROM ((((musicbrainz.l_series_work lsw
     JOIN musicbrainz.series s ON ((s.id = lsw.entity0)))
     JOIN musicbrainz.link l ON ((l.id = lsw.link)))
     JOIN musicbrainz.link_type lt ON (((lt.id = l.link_type) AND (lt.gid = 'b0d44366-cdf0-3acb-bee6-0f65a77a6ef0'::uuid))))
     LEFT JOIN musicbrainz.link_attribute_text_value latv ON (((latv.attribute_type = s.ordering_attribute) AND (latv.link = l.id))))
  ORDER BY lsw.entity0, lsw.link_order;



CREATE TABLE musicbrainz.work_tag (
    work integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL,
    last_updated timestamp with time zone DEFAULT now()
);



CREATE TABLE musicbrainz.work_tag_raw (
    work integer NOT NULL,
    editor integer NOT NULL,
    tag integer NOT NULL,
    is_upvote boolean DEFAULT true NOT NULL
);



CREATE TABLE musicbrainz.work_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent integer,
    child_order integer DEFAULT 0 NOT NULL,
    description text,
    gid uuid NOT NULL
);



CREATE SEQUENCE musicbrainz.work_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE musicbrainz.work_type_id_seq OWNED BY musicbrainz.work_type.id;



CREATE TABLE statistics.log_statistic (
    name text NOT NULL,
    category text NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    data text NOT NULL
);



CREATE TABLE statistics.statistic (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    value integer NOT NULL,
    date_collected date DEFAULT now() NOT NULL
);



CREATE TABLE statistics.statistic_event (
    date date NOT NULL,
    title text NOT NULL,
    link text NOT NULL,
    description text NOT NULL,
    CONSTRAINT statistic_event_date_check CHECK ((date >= '2000-01-01'::date))
);



CREATE SEQUENCE statistics.statistic_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE statistics.statistic_id_seq OWNED BY statistics.statistic.id;



CREATE TABLE wikidocs.wikidocs_index (
    page_name text NOT NULL,
    revision integer NOT NULL
);



ALTER TABLE ONLY cover_art_archive.art_type ALTER COLUMN id SET DEFAULT nextval('cover_art_archive.art_type_id_seq'::regclass);



ALTER TABLE ONLY event_art_archive.art_type ALTER COLUMN id SET DEFAULT nextval('event_art_archive.art_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.alternative_medium ALTER COLUMN id SET DEFAULT nextval('musicbrainz.alternative_medium_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.alternative_release ALTER COLUMN id SET DEFAULT nextval('musicbrainz.alternative_release_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.alternative_release_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.alternative_release_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.alternative_track ALTER COLUMN id SET DEFAULT nextval('musicbrainz.alternative_track_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.annotation ALTER COLUMN id SET DEFAULT nextval('musicbrainz.annotation_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.application ALTER COLUMN id SET DEFAULT nextval('musicbrainz.application_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.area ALTER COLUMN id SET DEFAULT nextval('musicbrainz.area_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.area_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.area_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.area_alias_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.area_alias_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.area_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.area_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.area_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.area_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.area_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.area_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.area_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.area_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.artist ALTER COLUMN id SET DEFAULT nextval('musicbrainz.artist_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.artist_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.artist_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.artist_alias_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.artist_alias_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.artist_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.artist_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.artist_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.artist_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.artist_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.artist_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.artist_credit ALTER COLUMN id SET DEFAULT nextval('musicbrainz.artist_credit_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.artist_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.artist_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.autoeditor_election ALTER COLUMN id SET DEFAULT nextval('musicbrainz.autoeditor_election_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.autoeditor_election_vote ALTER COLUMN id SET DEFAULT nextval('musicbrainz.autoeditor_election_vote_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.cdtoc ALTER COLUMN id SET DEFAULT nextval('musicbrainz.cdtoc_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.cdtoc_raw ALTER COLUMN id SET DEFAULT nextval('musicbrainz.cdtoc_raw_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.edit ALTER COLUMN id SET DEFAULT nextval('musicbrainz.edit_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.edit_note ALTER COLUMN id SET DEFAULT nextval('musicbrainz.edit_note_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.editor ALTER COLUMN id SET DEFAULT nextval('musicbrainz.editor_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.editor_collection ALTER COLUMN id SET DEFAULT nextval('musicbrainz.editor_collection_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.editor_collection_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.editor_collection_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.editor_oauth_token ALTER COLUMN id SET DEFAULT nextval('musicbrainz.editor_oauth_token_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.editor_preference ALTER COLUMN id SET DEFAULT nextval('musicbrainz.editor_preference_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.editor_subscribe_artist ALTER COLUMN id SET DEFAULT nextval('musicbrainz.editor_subscribe_artist_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.editor_subscribe_collection ALTER COLUMN id SET DEFAULT nextval('musicbrainz.editor_subscribe_collection_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.editor_subscribe_editor ALTER COLUMN id SET DEFAULT nextval('musicbrainz.editor_subscribe_editor_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.editor_subscribe_label ALTER COLUMN id SET DEFAULT nextval('musicbrainz.editor_subscribe_label_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.editor_subscribe_series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.editor_subscribe_series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.event ALTER COLUMN id SET DEFAULT nextval('musicbrainz.event_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.event_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.event_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.event_alias_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.event_alias_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.event_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.event_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.event_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.event_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.event_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.event_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.event_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.event_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.gender ALTER COLUMN id SET DEFAULT nextval('musicbrainz.gender_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.genre ALTER COLUMN id SET DEFAULT nextval('musicbrainz.genre_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.genre_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.genre_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.instrument ALTER COLUMN id SET DEFAULT nextval('musicbrainz.instrument_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.instrument_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.instrument_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.instrument_alias_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.instrument_alias_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.instrument_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.instrument_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.instrument_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.instrument_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.instrument_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.instrument_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.instrument_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.instrument_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.isrc ALTER COLUMN id SET DEFAULT nextval('musicbrainz.isrc_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.iswc ALTER COLUMN id SET DEFAULT nextval('musicbrainz.iswc_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_area ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_area_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_artist ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_artist_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_event ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_event_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_instrument ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_instrument_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_label ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_label_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_place ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_place_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_recording ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_recording_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_release ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_release_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_release_group ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_release_group_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_area_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_area_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_artist_artist ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_artist_artist_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_artist_event ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_artist_event_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_artist_instrument ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_artist_instrument_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_artist_label ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_artist_label_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_artist_place ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_artist_place_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_artist_recording ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_artist_recording_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_artist_release ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_artist_release_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_artist_release_group ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_artist_release_group_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_artist_series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_artist_series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_artist_url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_artist_url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_artist_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_artist_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_event_event ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_event_event_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_event_instrument ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_event_instrument_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_event_label ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_event_label_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_event_place ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_event_place_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_event_recording ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_event_recording_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_event_release ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_event_release_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_event_release_group ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_event_release_group_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_event_series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_event_series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_event_url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_event_url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_event_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_event_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_instrument_instrument ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_instrument_instrument_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_instrument_label ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_instrument_label_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_instrument_place ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_instrument_place_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_instrument_recording ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_instrument_recording_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_instrument_release ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_instrument_release_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_instrument_release_group ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_instrument_release_group_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_instrument_series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_instrument_series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_instrument_url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_instrument_url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_instrument_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_instrument_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_label_label ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_label_label_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_label_place ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_label_place_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_label_recording ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_label_recording_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_label_release ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_label_release_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_label_release_group ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_label_release_group_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_label_series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_label_series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_label_url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_label_url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_label_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_label_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_place_place ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_place_place_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_place_recording ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_place_recording_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_place_release ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_place_release_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_place_release_group ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_place_release_group_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_place_series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_place_series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_place_url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_place_url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_place_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_place_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_recording_recording ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_recording_recording_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_recording_release ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_recording_release_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_recording_release_group ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_recording_release_group_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_recording_series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_recording_series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_recording_url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_recording_url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_recording_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_recording_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_release_group_release_group ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_release_group_release_group_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_release_group_series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_release_group_series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_release_group_url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_release_group_url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_release_group_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_release_group_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_release_release ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_release_release_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_release_release_group ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_release_release_group_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_release_series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_release_series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_release_url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_release_url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_release_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_release_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_series_series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_series_series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_series_url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_series_url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_series_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_series_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_url_url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_url_url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_url_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_url_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.l_work_work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.l_work_work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.label ALTER COLUMN id SET DEFAULT nextval('musicbrainz.label_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.label_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.label_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.label_alias_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.label_alias_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.label_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.label_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.label_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.label_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.label_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.label_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.label_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.label_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.language ALTER COLUMN id SET DEFAULT nextval('musicbrainz.language_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.link ALTER COLUMN id SET DEFAULT nextval('musicbrainz.link_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.link_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.link_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.link_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.link_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.medium ALTER COLUMN id SET DEFAULT nextval('musicbrainz.medium_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.medium_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.medium_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.medium_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.medium_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.medium_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.medium_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.medium_cdtoc ALTER COLUMN id SET DEFAULT nextval('musicbrainz.medium_cdtoc_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.medium_format ALTER COLUMN id SET DEFAULT nextval('musicbrainz.medium_format_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.place ALTER COLUMN id SET DEFAULT nextval('musicbrainz.place_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.place_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.place_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.place_alias_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.place_alias_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.place_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.place_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.place_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.place_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.place_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.place_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.place_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.place_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.recording ALTER COLUMN id SET DEFAULT nextval('musicbrainz.recording_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.recording_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.recording_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.recording_alias_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.recording_alias_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.recording_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.recording_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.recording_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.recording_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.recording_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.recording_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_alias_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_alias_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_group ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_group_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_group_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_group_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_group_alias_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_group_alias_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_group_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_group_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_group_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_group_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_group_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_group_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_group_primary_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_group_primary_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_group_secondary_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_group_secondary_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_label ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_label_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_packaging ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_packaging_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_raw ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_raw_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.release_status ALTER COLUMN id SET DEFAULT nextval('musicbrainz.release_status_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.replication_control ALTER COLUMN id SET DEFAULT nextval('musicbrainz.replication_control_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.script ALTER COLUMN id SET DEFAULT nextval('musicbrainz.script_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.series ALTER COLUMN id SET DEFAULT nextval('musicbrainz.series_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.series_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.series_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.series_alias_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.series_alias_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.series_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.series_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.series_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.series_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.series_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.series_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.series_ordering_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.series_ordering_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.series_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.series_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.tag ALTER COLUMN id SET DEFAULT nextval('musicbrainz.tag_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.track ALTER COLUMN id SET DEFAULT nextval('musicbrainz.track_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.track_raw ALTER COLUMN id SET DEFAULT nextval('musicbrainz.track_raw_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.url ALTER COLUMN id SET DEFAULT nextval('musicbrainz.url_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.vote ALTER COLUMN id SET DEFAULT nextval('musicbrainz.vote_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.work ALTER COLUMN id SET DEFAULT nextval('musicbrainz.work_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.work_alias ALTER COLUMN id SET DEFAULT nextval('musicbrainz.work_alias_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.work_alias_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.work_alias_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.work_attribute ALTER COLUMN id SET DEFAULT nextval('musicbrainz.work_attribute_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.work_attribute_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.work_attribute_type_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.work_attribute_type_allowed_value ALTER COLUMN id SET DEFAULT nextval('musicbrainz.work_attribute_type_allowed_value_id_seq'::regclass);



ALTER TABLE ONLY musicbrainz.work_type ALTER COLUMN id SET DEFAULT nextval('musicbrainz.work_type_id_seq'::regclass);



ALTER TABLE ONLY statistics.statistic ALTER COLUMN id SET DEFAULT nextval('statistics.statistic_id_seq'::regclass);



ALTER TABLE ONLY cover_art_archive.art_type
    ADD CONSTRAINT art_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY cover_art_archive.cover_art
    ADD CONSTRAINT cover_art_pkey PRIMARY KEY (id);



ALTER TABLE ONLY cover_art_archive.cover_art_type
    ADD CONSTRAINT cover_art_type_pkey PRIMARY KEY (id, type_id);



ALTER TABLE ONLY cover_art_archive.image_type
    ADD CONSTRAINT image_type_pkey PRIMARY KEY (mime_type);



ALTER TABLE ONLY cover_art_archive.release_group_cover_art
    ADD CONSTRAINT release_group_cover_art_pkey PRIMARY KEY (release_group);



ALTER TABLE ONLY documentation.l_area_area_example
    ADD CONSTRAINT l_area_area_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_area_artist_example
    ADD CONSTRAINT l_area_artist_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_area_event_example
    ADD CONSTRAINT l_area_event_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_area_instrument_example
    ADD CONSTRAINT l_area_instrument_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_area_label_example
    ADD CONSTRAINT l_area_label_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_area_place_example
    ADD CONSTRAINT l_area_place_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_area_recording_example
    ADD CONSTRAINT l_area_recording_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_area_release_example
    ADD CONSTRAINT l_area_release_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_area_release_group_example
    ADD CONSTRAINT l_area_release_group_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_area_series_example
    ADD CONSTRAINT l_area_series_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_area_url_example
    ADD CONSTRAINT l_area_url_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_area_work_example
    ADD CONSTRAINT l_area_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_artist_artist_example
    ADD CONSTRAINT l_artist_artist_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_artist_event_example
    ADD CONSTRAINT l_artist_event_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_artist_instrument_example
    ADD CONSTRAINT l_artist_instrument_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_artist_label_example
    ADD CONSTRAINT l_artist_label_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_artist_place_example
    ADD CONSTRAINT l_artist_place_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_artist_recording_example
    ADD CONSTRAINT l_artist_recording_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_artist_release_example
    ADD CONSTRAINT l_artist_release_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_artist_release_group_example
    ADD CONSTRAINT l_artist_release_group_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_artist_series_example
    ADD CONSTRAINT l_artist_series_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_artist_url_example
    ADD CONSTRAINT l_artist_url_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_artist_work_example
    ADD CONSTRAINT l_artist_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_event_event_example
    ADD CONSTRAINT l_event_event_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_event_instrument_example
    ADD CONSTRAINT l_event_instrument_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_event_label_example
    ADD CONSTRAINT l_event_label_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_event_place_example
    ADD CONSTRAINT l_event_place_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_event_recording_example
    ADD CONSTRAINT l_event_recording_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_event_release_example
    ADD CONSTRAINT l_event_release_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_event_release_group_example
    ADD CONSTRAINT l_event_release_group_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_event_series_example
    ADD CONSTRAINT l_event_series_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_event_url_example
    ADD CONSTRAINT l_event_url_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_event_work_example
    ADD CONSTRAINT l_event_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_instrument_instrument_example
    ADD CONSTRAINT l_instrument_instrument_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_instrument_label_example
    ADD CONSTRAINT l_instrument_label_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_instrument_place_example
    ADD CONSTRAINT l_instrument_place_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_instrument_recording_example
    ADD CONSTRAINT l_instrument_recording_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_instrument_release_example
    ADD CONSTRAINT l_instrument_release_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_instrument_release_group_example
    ADD CONSTRAINT l_instrument_release_group_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_instrument_series_example
    ADD CONSTRAINT l_instrument_series_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_instrument_url_example
    ADD CONSTRAINT l_instrument_url_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_instrument_work_example
    ADD CONSTRAINT l_instrument_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_label_label_example
    ADD CONSTRAINT l_label_label_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_label_place_example
    ADD CONSTRAINT l_label_place_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_label_recording_example
    ADD CONSTRAINT l_label_recording_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_label_release_example
    ADD CONSTRAINT l_label_release_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_label_release_group_example
    ADD CONSTRAINT l_label_release_group_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_label_series_example
    ADD CONSTRAINT l_label_series_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_label_url_example
    ADD CONSTRAINT l_label_url_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_label_work_example
    ADD CONSTRAINT l_label_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_place_place_example
    ADD CONSTRAINT l_place_place_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_place_recording_example
    ADD CONSTRAINT l_place_recording_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_place_release_example
    ADD CONSTRAINT l_place_release_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_place_release_group_example
    ADD CONSTRAINT l_place_release_group_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_place_series_example
    ADD CONSTRAINT l_place_series_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_place_url_example
    ADD CONSTRAINT l_place_url_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_place_work_example
    ADD CONSTRAINT l_place_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_recording_recording_example
    ADD CONSTRAINT l_recording_recording_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_recording_release_example
    ADD CONSTRAINT l_recording_release_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_recording_release_group_example
    ADD CONSTRAINT l_recording_release_group_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_recording_series_example
    ADD CONSTRAINT l_recording_series_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_recording_url_example
    ADD CONSTRAINT l_recording_url_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_recording_work_example
    ADD CONSTRAINT l_recording_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_release_group_release_group_example
    ADD CONSTRAINT l_release_group_release_group_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_release_group_series_example
    ADD CONSTRAINT l_release_group_series_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_release_group_url_example
    ADD CONSTRAINT l_release_group_url_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_release_group_work_example
    ADD CONSTRAINT l_release_group_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_release_release_example
    ADD CONSTRAINT l_release_release_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_release_release_group_example
    ADD CONSTRAINT l_release_release_group_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_release_series_example
    ADD CONSTRAINT l_release_series_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_release_url_example
    ADD CONSTRAINT l_release_url_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_release_work_example
    ADD CONSTRAINT l_release_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_series_series_example
    ADD CONSTRAINT l_series_series_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_series_url_example
    ADD CONSTRAINT l_series_url_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_series_work_example
    ADD CONSTRAINT l_series_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_url_url_example
    ADD CONSTRAINT l_url_url_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_url_work_example
    ADD CONSTRAINT l_url_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.l_work_work_example
    ADD CONSTRAINT l_work_work_example_pkey PRIMARY KEY (id);



ALTER TABLE ONLY documentation.link_type_documentation
    ADD CONSTRAINT link_type_documentation_pkey PRIMARY KEY (id);



ALTER TABLE ONLY event_art_archive.art_type
    ADD CONSTRAINT art_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY event_art_archive.event_art
    ADD CONSTRAINT event_art_pkey PRIMARY KEY (id);



ALTER TABLE ONLY event_art_archive.event_art_type
    ADD CONSTRAINT event_art_type_pkey PRIMARY KEY (id, type_id);



ALTER TABLE ONLY musicbrainz.alternative_medium
    ADD CONSTRAINT alternative_medium_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.alternative_medium_track
    ADD CONSTRAINT alternative_medium_track_pkey PRIMARY KEY (alternative_medium, track);



ALTER TABLE ONLY musicbrainz.alternative_release
    ADD CONSTRAINT alternative_release_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.alternative_release_type
    ADD CONSTRAINT alternative_release_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.alternative_track
    ADD CONSTRAINT alternative_track_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.annotation
    ADD CONSTRAINT annotation_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.application
    ADD CONSTRAINT application_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.area_alias
    ADD CONSTRAINT area_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.area_alias_type
    ADD CONSTRAINT area_alias_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.area_annotation
    ADD CONSTRAINT area_annotation_pkey PRIMARY KEY (area, annotation);



ALTER TABLE ONLY musicbrainz.area_attribute
    ADD CONSTRAINT area_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.area_attribute_type_allowed_value
    ADD CONSTRAINT area_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.area_attribute_type
    ADD CONSTRAINT area_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.area_gid_redirect
    ADD CONSTRAINT area_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.area
    ADD CONSTRAINT area_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.area_tag
    ADD CONSTRAINT area_tag_pkey PRIMARY KEY (area, tag);



ALTER TABLE ONLY musicbrainz.area_tag_raw
    ADD CONSTRAINT area_tag_raw_pkey PRIMARY KEY (area, editor, tag);



ALTER TABLE ONLY musicbrainz.area_type
    ADD CONSTRAINT area_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.artist_alias
    ADD CONSTRAINT artist_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.artist_alias_type
    ADD CONSTRAINT artist_alias_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.artist_annotation
    ADD CONSTRAINT artist_annotation_pkey PRIMARY KEY (artist, annotation);



ALTER TABLE ONLY musicbrainz.artist_attribute
    ADD CONSTRAINT artist_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.artist_attribute_type_allowed_value
    ADD CONSTRAINT artist_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.artist_attribute_type
    ADD CONSTRAINT artist_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.artist_credit_name
    ADD CONSTRAINT artist_credit_name_pkey PRIMARY KEY (artist_credit, "position");



ALTER TABLE ONLY musicbrainz.artist_credit
    ADD CONSTRAINT artist_credit_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.artist_gid_redirect
    ADD CONSTRAINT artist_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.artist_ipi
    ADD CONSTRAINT artist_ipi_pkey PRIMARY KEY (artist, ipi);



ALTER TABLE ONLY musicbrainz.artist_isni
    ADD CONSTRAINT artist_isni_pkey PRIMARY KEY (artist, isni);



ALTER TABLE ONLY musicbrainz.artist_meta
    ADD CONSTRAINT artist_meta_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.artist
    ADD CONSTRAINT artist_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.artist_rating_raw
    ADD CONSTRAINT artist_rating_raw_pkey PRIMARY KEY (artist, editor);



ALTER TABLE ONLY musicbrainz.artist_tag
    ADD CONSTRAINT artist_tag_pkey PRIMARY KEY (artist, tag);



ALTER TABLE ONLY musicbrainz.artist_tag_raw
    ADD CONSTRAINT artist_tag_raw_pkey PRIMARY KEY (artist, editor, tag);



ALTER TABLE ONLY musicbrainz.artist_type
    ADD CONSTRAINT artist_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.autoeditor_election
    ADD CONSTRAINT autoeditor_election_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.autoeditor_election_vote
    ADD CONSTRAINT autoeditor_election_vote_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.cdtoc
    ADD CONSTRAINT cdtoc_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.cdtoc_raw
    ADD CONSTRAINT cdtoc_raw_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.country_area
    ADD CONSTRAINT country_area_pkey PRIMARY KEY (area);



ALTER TABLE ONLY musicbrainz.deleted_entity
    ADD CONSTRAINT deleted_entity_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.edit_area
    ADD CONSTRAINT edit_area_pkey PRIMARY KEY (edit, area);



ALTER TABLE ONLY musicbrainz.edit_artist
    ADD CONSTRAINT edit_artist_pkey PRIMARY KEY (edit, artist);



ALTER TABLE ONLY musicbrainz.edit_data
    ADD CONSTRAINT edit_data_pkey PRIMARY KEY (edit);



ALTER TABLE ONLY musicbrainz.edit_event
    ADD CONSTRAINT edit_event_pkey PRIMARY KEY (edit, event);



ALTER TABLE ONLY musicbrainz.edit_instrument
    ADD CONSTRAINT edit_instrument_pkey PRIMARY KEY (edit, instrument);



ALTER TABLE ONLY musicbrainz.edit_label
    ADD CONSTRAINT edit_label_pkey PRIMARY KEY (edit, label);



ALTER TABLE ONLY musicbrainz.edit_note
    ADD CONSTRAINT edit_note_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.edit_note_recipient
    ADD CONSTRAINT edit_note_recipient_pkey PRIMARY KEY (recipient, edit_note);



ALTER TABLE ONLY musicbrainz.edit
    ADD CONSTRAINT edit_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.edit_place
    ADD CONSTRAINT edit_place_pkey PRIMARY KEY (edit, place);



ALTER TABLE ONLY musicbrainz.edit_recording
    ADD CONSTRAINT edit_recording_pkey PRIMARY KEY (edit, recording);



ALTER TABLE ONLY musicbrainz.edit_release_group
    ADD CONSTRAINT edit_release_group_pkey PRIMARY KEY (edit, release_group);



ALTER TABLE ONLY musicbrainz.edit_release
    ADD CONSTRAINT edit_release_pkey PRIMARY KEY (edit, release);



ALTER TABLE ONLY musicbrainz.edit_series
    ADD CONSTRAINT edit_series_pkey PRIMARY KEY (edit, series);



ALTER TABLE ONLY musicbrainz.edit_url
    ADD CONSTRAINT edit_url_pkey PRIMARY KEY (edit, url);



ALTER TABLE ONLY musicbrainz.edit_work
    ADD CONSTRAINT edit_work_pkey PRIMARY KEY (edit, work);



ALTER TABLE ONLY musicbrainz.editor_collection_area
    ADD CONSTRAINT editor_collection_area_pkey PRIMARY KEY (collection, area);



ALTER TABLE ONLY musicbrainz.editor_collection_artist
    ADD CONSTRAINT editor_collection_artist_pkey PRIMARY KEY (collection, artist);



ALTER TABLE ONLY musicbrainz.editor_collection_collaborator
    ADD CONSTRAINT editor_collection_collaborator_pkey PRIMARY KEY (collection, editor);



ALTER TABLE ONLY musicbrainz.editor_collection_deleted_entity
    ADD CONSTRAINT editor_collection_deleted_entity_pkey PRIMARY KEY (collection, gid);



ALTER TABLE ONLY musicbrainz.editor_collection_event
    ADD CONSTRAINT editor_collection_event_pkey PRIMARY KEY (collection, event);



ALTER TABLE ONLY musicbrainz.editor_collection_instrument
    ADD CONSTRAINT editor_collection_instrument_pkey PRIMARY KEY (collection, instrument);



ALTER TABLE ONLY musicbrainz.editor_collection_label
    ADD CONSTRAINT editor_collection_label_pkey PRIMARY KEY (collection, label);



ALTER TABLE ONLY musicbrainz.editor_collection
    ADD CONSTRAINT editor_collection_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.editor_collection_place
    ADD CONSTRAINT editor_collection_place_pkey PRIMARY KEY (collection, place);



ALTER TABLE ONLY musicbrainz.editor_collection_recording
    ADD CONSTRAINT editor_collection_recording_pkey PRIMARY KEY (collection, recording);



ALTER TABLE ONLY musicbrainz.editor_collection_release_group
    ADD CONSTRAINT editor_collection_release_group_pkey PRIMARY KEY (collection, release_group);



ALTER TABLE ONLY musicbrainz.editor_collection_release
    ADD CONSTRAINT editor_collection_release_pkey PRIMARY KEY (collection, release);



ALTER TABLE ONLY musicbrainz.editor_collection_series
    ADD CONSTRAINT editor_collection_series_pkey PRIMARY KEY (collection, series);



ALTER TABLE ONLY musicbrainz.editor_collection_type
    ADD CONSTRAINT editor_collection_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.editor_collection_work
    ADD CONSTRAINT editor_collection_work_pkey PRIMARY KEY (collection, work);



ALTER TABLE ONLY musicbrainz.editor_language
    ADD CONSTRAINT editor_language_pkey PRIMARY KEY (editor, language);



ALTER TABLE ONLY musicbrainz.editor_oauth_token
    ADD CONSTRAINT editor_oauth_token_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.editor
    ADD CONSTRAINT editor_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.editor_preference
    ADD CONSTRAINT editor_preference_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.editor_subscribe_artist_deleted
    ADD CONSTRAINT editor_subscribe_artist_deleted_pkey PRIMARY KEY (editor, gid);



ALTER TABLE ONLY musicbrainz.editor_subscribe_artist
    ADD CONSTRAINT editor_subscribe_artist_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.editor_subscribe_collection
    ADD CONSTRAINT editor_subscribe_collection_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.editor_subscribe_editor
    ADD CONSTRAINT editor_subscribe_editor_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.editor_subscribe_label_deleted
    ADD CONSTRAINT editor_subscribe_label_deleted_pkey PRIMARY KEY (editor, gid);



ALTER TABLE ONLY musicbrainz.editor_subscribe_label
    ADD CONSTRAINT editor_subscribe_label_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.editor_subscribe_series_deleted
    ADD CONSTRAINT editor_subscribe_series_deleted_pkey PRIMARY KEY (editor, gid);



ALTER TABLE ONLY musicbrainz.editor_subscribe_series
    ADD CONSTRAINT editor_subscribe_series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.editor_watch_artist
    ADD CONSTRAINT editor_watch_artist_pkey PRIMARY KEY (artist, editor);



ALTER TABLE ONLY musicbrainz.editor_watch_preferences
    ADD CONSTRAINT editor_watch_preferences_pkey PRIMARY KEY (editor);



ALTER TABLE ONLY musicbrainz.editor_watch_release_group_type
    ADD CONSTRAINT editor_watch_release_group_type_pkey PRIMARY KEY (editor, release_group_type);



ALTER TABLE ONLY musicbrainz.editor_watch_release_status
    ADD CONSTRAINT editor_watch_release_status_pkey PRIMARY KEY (editor, release_status);



ALTER TABLE ONLY musicbrainz.event_alias
    ADD CONSTRAINT event_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.event_alias_type
    ADD CONSTRAINT event_alias_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.event_annotation
    ADD CONSTRAINT event_annotation_pkey PRIMARY KEY (event, annotation);



ALTER TABLE ONLY musicbrainz.event_attribute
    ADD CONSTRAINT event_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.event_attribute_type_allowed_value
    ADD CONSTRAINT event_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.event_attribute_type
    ADD CONSTRAINT event_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.event_gid_redirect
    ADD CONSTRAINT event_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.event_meta
    ADD CONSTRAINT event_meta_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.event
    ADD CONSTRAINT event_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.event_rating_raw
    ADD CONSTRAINT event_rating_raw_pkey PRIMARY KEY (event, editor);



ALTER TABLE ONLY musicbrainz.event_tag
    ADD CONSTRAINT event_tag_pkey PRIMARY KEY (event, tag);



ALTER TABLE ONLY musicbrainz.event_tag_raw
    ADD CONSTRAINT event_tag_raw_pkey PRIMARY KEY (event, editor, tag);



ALTER TABLE ONLY musicbrainz.event_type
    ADD CONSTRAINT event_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.gender
    ADD CONSTRAINT gender_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.genre_alias
    ADD CONSTRAINT genre_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.genre
    ADD CONSTRAINT genre_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.instrument_alias
    ADD CONSTRAINT instrument_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.instrument_alias_type
    ADD CONSTRAINT instrument_alias_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.instrument_annotation
    ADD CONSTRAINT instrument_annotation_pkey PRIMARY KEY (instrument, annotation);



ALTER TABLE ONLY musicbrainz.instrument_attribute
    ADD CONSTRAINT instrument_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.instrument_attribute_type_allowed_value
    ADD CONSTRAINT instrument_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.instrument_attribute_type
    ADD CONSTRAINT instrument_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.instrument_gid_redirect
    ADD CONSTRAINT instrument_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.instrument
    ADD CONSTRAINT instrument_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.instrument_tag
    ADD CONSTRAINT instrument_tag_pkey PRIMARY KEY (instrument, tag);



ALTER TABLE ONLY musicbrainz.instrument_tag_raw
    ADD CONSTRAINT instrument_tag_raw_pkey PRIMARY KEY (instrument, editor, tag);



ALTER TABLE ONLY musicbrainz.instrument_type
    ADD CONSTRAINT instrument_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.iso_3166_1
    ADD CONSTRAINT iso_3166_1_pkey PRIMARY KEY (code);



ALTER TABLE ONLY musicbrainz.iso_3166_2
    ADD CONSTRAINT iso_3166_2_pkey PRIMARY KEY (code);



ALTER TABLE ONLY musicbrainz.iso_3166_3
    ADD CONSTRAINT iso_3166_3_pkey PRIMARY KEY (code);



ALTER TABLE ONLY musicbrainz.isrc
    ADD CONSTRAINT isrc_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.iswc
    ADD CONSTRAINT iswc_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_area
    ADD CONSTRAINT l_area_area_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_artist
    ADD CONSTRAINT l_area_artist_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_event
    ADD CONSTRAINT l_area_event_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_instrument
    ADD CONSTRAINT l_area_instrument_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_label
    ADD CONSTRAINT l_area_label_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_place
    ADD CONSTRAINT l_area_place_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_recording
    ADD CONSTRAINT l_area_recording_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_release_group
    ADD CONSTRAINT l_area_release_group_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_release
    ADD CONSTRAINT l_area_release_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_series
    ADD CONSTRAINT l_area_series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_url
    ADD CONSTRAINT l_area_url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_area_work
    ADD CONSTRAINT l_area_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_artist_artist
    ADD CONSTRAINT l_artist_artist_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_artist_event
    ADD CONSTRAINT l_artist_event_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_artist_instrument
    ADD CONSTRAINT l_artist_instrument_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_artist_label
    ADD CONSTRAINT l_artist_label_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_artist_place
    ADD CONSTRAINT l_artist_place_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_artist_recording
    ADD CONSTRAINT l_artist_recording_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_artist_release_group
    ADD CONSTRAINT l_artist_release_group_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_artist_release
    ADD CONSTRAINT l_artist_release_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_artist_series
    ADD CONSTRAINT l_artist_series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_artist_url
    ADD CONSTRAINT l_artist_url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_artist_work
    ADD CONSTRAINT l_artist_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_event_event
    ADD CONSTRAINT l_event_event_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_event_instrument
    ADD CONSTRAINT l_event_instrument_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_event_label
    ADD CONSTRAINT l_event_label_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_event_place
    ADD CONSTRAINT l_event_place_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_event_recording
    ADD CONSTRAINT l_event_recording_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_event_release_group
    ADD CONSTRAINT l_event_release_group_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_event_release
    ADD CONSTRAINT l_event_release_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_event_series
    ADD CONSTRAINT l_event_series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_event_url
    ADD CONSTRAINT l_event_url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_event_work
    ADD CONSTRAINT l_event_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_instrument_instrument
    ADD CONSTRAINT l_instrument_instrument_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_instrument_label
    ADD CONSTRAINT l_instrument_label_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_instrument_place
    ADD CONSTRAINT l_instrument_place_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_instrument_recording
    ADD CONSTRAINT l_instrument_recording_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_instrument_release_group
    ADD CONSTRAINT l_instrument_release_group_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_instrument_release
    ADD CONSTRAINT l_instrument_release_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_instrument_series
    ADD CONSTRAINT l_instrument_series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_instrument_url
    ADD CONSTRAINT l_instrument_url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_instrument_work
    ADD CONSTRAINT l_instrument_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_label_label
    ADD CONSTRAINT l_label_label_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_label_place
    ADD CONSTRAINT l_label_place_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_label_recording
    ADD CONSTRAINT l_label_recording_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_label_release_group
    ADD CONSTRAINT l_label_release_group_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_label_release
    ADD CONSTRAINT l_label_release_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_label_series
    ADD CONSTRAINT l_label_series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_label_url
    ADD CONSTRAINT l_label_url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_label_work
    ADD CONSTRAINT l_label_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_place_place
    ADD CONSTRAINT l_place_place_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_place_recording
    ADD CONSTRAINT l_place_recording_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_place_release_group
    ADD CONSTRAINT l_place_release_group_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_place_release
    ADD CONSTRAINT l_place_release_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_place_series
    ADD CONSTRAINT l_place_series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_place_url
    ADD CONSTRAINT l_place_url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_place_work
    ADD CONSTRAINT l_place_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_recording_recording
    ADD CONSTRAINT l_recording_recording_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_recording_release_group
    ADD CONSTRAINT l_recording_release_group_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_recording_release
    ADD CONSTRAINT l_recording_release_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_recording_series
    ADD CONSTRAINT l_recording_series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_recording_url
    ADD CONSTRAINT l_recording_url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_recording_work
    ADD CONSTRAINT l_recording_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_release_group_release_group
    ADD CONSTRAINT l_release_group_release_group_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_release_group_series
    ADD CONSTRAINT l_release_group_series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_release_group_url
    ADD CONSTRAINT l_release_group_url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_release_group_work
    ADD CONSTRAINT l_release_group_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_release_release_group
    ADD CONSTRAINT l_release_release_group_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_release_release
    ADD CONSTRAINT l_release_release_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_release_series
    ADD CONSTRAINT l_release_series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_release_url
    ADD CONSTRAINT l_release_url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_release_work
    ADD CONSTRAINT l_release_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_series_series
    ADD CONSTRAINT l_series_series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_series_url
    ADD CONSTRAINT l_series_url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_series_work
    ADD CONSTRAINT l_series_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_url_url
    ADD CONSTRAINT l_url_url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_url_work
    ADD CONSTRAINT l_url_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.l_work_work
    ADD CONSTRAINT l_work_work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.label_alias
    ADD CONSTRAINT label_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.label_alias_type
    ADD CONSTRAINT label_alias_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.label_annotation
    ADD CONSTRAINT label_annotation_pkey PRIMARY KEY (label, annotation);



ALTER TABLE ONLY musicbrainz.label_attribute
    ADD CONSTRAINT label_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.label_attribute_type_allowed_value
    ADD CONSTRAINT label_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.label_attribute_type
    ADD CONSTRAINT label_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.label_gid_redirect
    ADD CONSTRAINT label_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.label_ipi
    ADD CONSTRAINT label_ipi_pkey PRIMARY KEY (label, ipi);



ALTER TABLE ONLY musicbrainz.label_isni
    ADD CONSTRAINT label_isni_pkey PRIMARY KEY (label, isni);



ALTER TABLE ONLY musicbrainz.label_meta
    ADD CONSTRAINT label_meta_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.label
    ADD CONSTRAINT label_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.label_rating_raw
    ADD CONSTRAINT label_rating_raw_pkey PRIMARY KEY (label, editor);



ALTER TABLE ONLY musicbrainz.label_tag
    ADD CONSTRAINT label_tag_pkey PRIMARY KEY (label, tag);



ALTER TABLE ONLY musicbrainz.label_tag_raw
    ADD CONSTRAINT label_tag_raw_pkey PRIMARY KEY (label, editor, tag);



ALTER TABLE ONLY musicbrainz.label_type
    ADD CONSTRAINT label_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.language
    ADD CONSTRAINT language_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.link_attribute_credit
    ADD CONSTRAINT link_attribute_credit_pkey PRIMARY KEY (link, attribute_type);



ALTER TABLE ONLY musicbrainz.link_attribute
    ADD CONSTRAINT link_attribute_pkey PRIMARY KEY (link, attribute_type);



ALTER TABLE ONLY musicbrainz.link_attribute_text_value
    ADD CONSTRAINT link_attribute_text_value_pkey PRIMARY KEY (link, attribute_type);



ALTER TABLE ONLY musicbrainz.link_attribute_type
    ADD CONSTRAINT link_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.link_creditable_attribute_type
    ADD CONSTRAINT link_creditable_attribute_type_pkey PRIMARY KEY (attribute_type);



ALTER TABLE ONLY musicbrainz.link
    ADD CONSTRAINT link_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.link_text_attribute_type
    ADD CONSTRAINT link_text_attribute_type_pkey PRIMARY KEY (attribute_type);



ALTER TABLE ONLY musicbrainz.link_type_attribute_type
    ADD CONSTRAINT link_type_attribute_type_pkey PRIMARY KEY (link_type, attribute_type);



ALTER TABLE ONLY musicbrainz.link_type
    ADD CONSTRAINT link_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.medium_attribute
    ADD CONSTRAINT medium_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.medium_attribute_type_allowed_format
    ADD CONSTRAINT medium_attribute_type_allowed_format_pkey PRIMARY KEY (medium_format, medium_attribute_type);



ALTER TABLE ONLY musicbrainz.medium_attribute_type_allowed_value_allowed_format
    ADD CONSTRAINT medium_attribute_type_allowed_value_allowed_format_pkey PRIMARY KEY (medium_format, medium_attribute_type_allowed_value);



ALTER TABLE ONLY musicbrainz.medium_attribute_type_allowed_value
    ADD CONSTRAINT medium_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.medium_attribute_type
    ADD CONSTRAINT medium_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.medium_cdtoc
    ADD CONSTRAINT medium_cdtoc_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.medium_format
    ADD CONSTRAINT medium_format_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.medium_index
    ADD CONSTRAINT medium_index_pkey PRIMARY KEY (medium);



ALTER TABLE ONLY musicbrainz.medium
    ADD CONSTRAINT medium_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.orderable_link_type
    ADD CONSTRAINT orderable_link_type_pkey PRIMARY KEY (link_type);



ALTER TABLE ONLY musicbrainz.place_alias
    ADD CONSTRAINT place_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.place_alias_type
    ADD CONSTRAINT place_alias_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.place_annotation
    ADD CONSTRAINT place_annotation_pkey PRIMARY KEY (place, annotation);



ALTER TABLE ONLY musicbrainz.place_attribute
    ADD CONSTRAINT place_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.place_attribute_type_allowed_value
    ADD CONSTRAINT place_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.place_attribute_type
    ADD CONSTRAINT place_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.place_gid_redirect
    ADD CONSTRAINT place_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.place
    ADD CONSTRAINT place_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.place_tag
    ADD CONSTRAINT place_tag_pkey PRIMARY KEY (place, tag);



ALTER TABLE ONLY musicbrainz.place_tag_raw
    ADD CONSTRAINT place_tag_raw_pkey PRIMARY KEY (place, editor, tag);



ALTER TABLE ONLY musicbrainz.place_type
    ADD CONSTRAINT place_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.recording_alias
    ADD CONSTRAINT recording_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.recording_alias_type
    ADD CONSTRAINT recording_alias_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.recording_annotation
    ADD CONSTRAINT recording_annotation_pkey PRIMARY KEY (recording, annotation);



ALTER TABLE ONLY musicbrainz.recording_attribute
    ADD CONSTRAINT recording_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.recording_attribute_type_allowed_value
    ADD CONSTRAINT recording_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.recording_attribute_type
    ADD CONSTRAINT recording_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.recording_gid_redirect
    ADD CONSTRAINT recording_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.recording_meta
    ADD CONSTRAINT recording_meta_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.recording
    ADD CONSTRAINT recording_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.recording_rating_raw
    ADD CONSTRAINT recording_rating_raw_pkey PRIMARY KEY (recording, editor);



ALTER TABLE ONLY musicbrainz.recording_tag
    ADD CONSTRAINT recording_tag_pkey PRIMARY KEY (recording, tag);



ALTER TABLE ONLY musicbrainz.recording_tag_raw
    ADD CONSTRAINT recording_tag_raw_pkey PRIMARY KEY (recording, editor, tag);



ALTER TABLE ONLY musicbrainz.release_alias
    ADD CONSTRAINT release_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_alias_type
    ADD CONSTRAINT release_alias_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_annotation
    ADD CONSTRAINT release_annotation_pkey PRIMARY KEY (release, annotation);



ALTER TABLE ONLY musicbrainz.release_attribute
    ADD CONSTRAINT release_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_attribute_type_allowed_value
    ADD CONSTRAINT release_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_attribute_type
    ADD CONSTRAINT release_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_country
    ADD CONSTRAINT release_country_pkey PRIMARY KEY (release, country);



ALTER TABLE ONLY musicbrainz.release_coverart
    ADD CONSTRAINT release_coverart_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_gid_redirect
    ADD CONSTRAINT release_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.release_group_alias
    ADD CONSTRAINT release_group_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_group_alias_type
    ADD CONSTRAINT release_group_alias_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_group_annotation
    ADD CONSTRAINT release_group_annotation_pkey PRIMARY KEY (release_group, annotation);



ALTER TABLE ONLY musicbrainz.release_group_attribute
    ADD CONSTRAINT release_group_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_group_attribute_type_allowed_value
    ADD CONSTRAINT release_group_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_group_attribute_type
    ADD CONSTRAINT release_group_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_group_gid_redirect
    ADD CONSTRAINT release_group_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.release_group_meta
    ADD CONSTRAINT release_group_meta_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_group
    ADD CONSTRAINT release_group_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_group_primary_type
    ADD CONSTRAINT release_group_primary_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_group_rating_raw
    ADD CONSTRAINT release_group_rating_raw_pkey PRIMARY KEY (release_group, editor);



ALTER TABLE ONLY musicbrainz.release_group_secondary_type_join
    ADD CONSTRAINT release_group_secondary_type_join_pkey PRIMARY KEY (release_group, secondary_type);



ALTER TABLE ONLY musicbrainz.release_group_secondary_type
    ADD CONSTRAINT release_group_secondary_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_group_tag
    ADD CONSTRAINT release_group_tag_pkey PRIMARY KEY (release_group, tag);



ALTER TABLE ONLY musicbrainz.release_group_tag_raw
    ADD CONSTRAINT release_group_tag_raw_pkey PRIMARY KEY (release_group, editor, tag);



ALTER TABLE ONLY musicbrainz.release_label
    ADD CONSTRAINT release_label_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_meta
    ADD CONSTRAINT release_meta_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_packaging
    ADD CONSTRAINT release_packaging_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release
    ADD CONSTRAINT release_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_raw
    ADD CONSTRAINT release_raw_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_status
    ADD CONSTRAINT release_status_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.release_tag
    ADD CONSTRAINT release_tag_pkey PRIMARY KEY (release, tag);



ALTER TABLE ONLY musicbrainz.release_tag_raw
    ADD CONSTRAINT release_tag_raw_pkey PRIMARY KEY (release, editor, tag);



ALTER TABLE ONLY musicbrainz.release_unknown_country
    ADD CONSTRAINT release_unknown_country_pkey PRIMARY KEY (release);



ALTER TABLE ONLY musicbrainz.replication_control
    ADD CONSTRAINT replication_control_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.script
    ADD CONSTRAINT script_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.series_alias
    ADD CONSTRAINT series_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.series_alias_type
    ADD CONSTRAINT series_alias_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.series_annotation
    ADD CONSTRAINT series_annotation_pkey PRIMARY KEY (series, annotation);



ALTER TABLE ONLY musicbrainz.series_attribute
    ADD CONSTRAINT series_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.series_attribute_type_allowed_value
    ADD CONSTRAINT series_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.series_attribute_type
    ADD CONSTRAINT series_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.series_gid_redirect
    ADD CONSTRAINT series_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.series_ordering_type
    ADD CONSTRAINT series_ordering_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.series
    ADD CONSTRAINT series_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.series_tag
    ADD CONSTRAINT series_tag_pkey PRIMARY KEY (series, tag);



ALTER TABLE ONLY musicbrainz.series_tag_raw
    ADD CONSTRAINT series_tag_raw_pkey PRIMARY KEY (series, editor, tag);



ALTER TABLE ONLY musicbrainz.series_type
    ADD CONSTRAINT series_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.tag
    ADD CONSTRAINT tag_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.tag_relation
    ADD CONSTRAINT tag_relation_pkey PRIMARY KEY (tag1, tag2);



ALTER TABLE ONLY musicbrainz.track_gid_redirect
    ADD CONSTRAINT track_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.track
    ADD CONSTRAINT track_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.track_raw
    ADD CONSTRAINT track_raw_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.url_gid_redirect
    ADD CONSTRAINT url_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.url
    ADD CONSTRAINT url_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.vote
    ADD CONSTRAINT vote_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.work_alias
    ADD CONSTRAINT work_alias_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.work_alias_type
    ADD CONSTRAINT work_alias_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.work_annotation
    ADD CONSTRAINT work_annotation_pkey PRIMARY KEY (work, annotation);



ALTER TABLE ONLY musicbrainz.work_attribute
    ADD CONSTRAINT work_attribute_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.work_attribute_type_allowed_value
    ADD CONSTRAINT work_attribute_type_allowed_value_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.work_attribute_type
    ADD CONSTRAINT work_attribute_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.work_gid_redirect
    ADD CONSTRAINT work_gid_redirect_pkey PRIMARY KEY (gid);



ALTER TABLE ONLY musicbrainz.work_language
    ADD CONSTRAINT work_language_pkey PRIMARY KEY (work, language);



ALTER TABLE ONLY musicbrainz.work_meta
    ADD CONSTRAINT work_meta_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.work
    ADD CONSTRAINT work_pkey PRIMARY KEY (id);



ALTER TABLE ONLY musicbrainz.work_rating_raw
    ADD CONSTRAINT work_rating_raw_pkey PRIMARY KEY (work, editor);



ALTER TABLE ONLY musicbrainz.work_tag
    ADD CONSTRAINT work_tag_pkey PRIMARY KEY (work, tag);



ALTER TABLE ONLY musicbrainz.work_tag_raw
    ADD CONSTRAINT work_tag_raw_pkey PRIMARY KEY (work, editor, tag);



ALTER TABLE ONLY musicbrainz.work_type
    ADD CONSTRAINT work_type_pkey PRIMARY KEY (id);



ALTER TABLE ONLY statistics.log_statistic
    ADD CONSTRAINT log_statistic_pkey PRIMARY KEY (name, category, "timestamp");



ALTER TABLE ONLY statistics.statistic_event
    ADD CONSTRAINT statistic_event_pkey PRIMARY KEY (date);



ALTER TABLE ONLY statistics.statistic
    ADD CONSTRAINT statistic_pkey PRIMARY KEY (id);



ALTER TABLE ONLY wikidocs.wikidocs_index
    ADD CONSTRAINT wikidocs_index_pkey PRIMARY KEY (page_name);



CREATE UNIQUE INDEX art_type_idx_gid ON cover_art_archive.art_type USING btree (gid);



CREATE INDEX cover_art_idx_release ON cover_art_archive.cover_art USING btree (release);



CREATE UNIQUE INDEX art_type_idx_gid ON event_art_archive.art_type USING btree (gid);



CREATE INDEX event_art_idx_event ON event_art_archive.event_art USING btree (event);



CREATE INDEX alternative_medium_idx_alternative_release ON musicbrainz.alternative_medium USING btree (alternative_release);



CREATE INDEX alternative_release_idx_artist_credit ON musicbrainz.alternative_release USING btree (artist_credit);



CREATE UNIQUE INDEX alternative_release_idx_gid ON musicbrainz.alternative_release USING btree (gid);



CREATE INDEX alternative_release_idx_language_script ON musicbrainz.alternative_release USING btree (language, script);



CREATE INDEX alternative_release_idx_name ON musicbrainz.alternative_release USING btree (name);



CREATE INDEX alternative_release_idx_release ON musicbrainz.alternative_release USING btree (release);



CREATE INDEX alternative_track_idx_artist_credit ON musicbrainz.alternative_track USING btree (artist_credit);



CREATE INDEX alternative_track_idx_name ON musicbrainz.alternative_track USING btree (name);



CREATE UNIQUE INDEX application_idx_oauth_id ON musicbrainz.application USING btree (oauth_id);



CREATE INDEX application_idx_owner ON musicbrainz.application USING btree (owner);



CREATE INDEX area_alias_idx_area ON musicbrainz.area_alias USING btree (area);



CREATE UNIQUE INDEX area_alias_idx_primary ON musicbrainz.area_alias USING btree (area, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE UNIQUE INDEX area_alias_type_idx_gid ON musicbrainz.area_alias_type USING btree (gid);



CREATE INDEX area_attribute_idx_area ON musicbrainz.area_attribute USING btree (area);



CREATE UNIQUE INDEX area_attribute_type_allowed_value_idx_gid ON musicbrainz.area_attribute_type_allowed_value USING btree (gid);



CREATE INDEX area_attribute_type_allowed_value_idx_name ON musicbrainz.area_attribute_type_allowed_value USING btree (area_attribute_type);



CREATE UNIQUE INDEX area_attribute_type_idx_gid ON musicbrainz.area_attribute_type USING btree (gid);



CREATE INDEX area_gid_redirect_idx_new_id ON musicbrainz.area_gid_redirect USING btree (new_id);



CREATE UNIQUE INDEX area_idx_gid ON musicbrainz.area USING btree (gid);



CREATE INDEX area_idx_name ON musicbrainz.area USING btree (name);



CREATE INDEX area_tag_idx_tag ON musicbrainz.area_tag USING btree (tag);



CREATE INDEX area_tag_raw_idx_area ON musicbrainz.area_tag_raw USING btree (area);



CREATE INDEX area_tag_raw_idx_editor ON musicbrainz.area_tag_raw USING btree (editor);



CREATE INDEX area_tag_raw_idx_tag ON musicbrainz.area_tag_raw USING btree (tag);



CREATE UNIQUE INDEX area_type_idx_gid ON musicbrainz.area_type USING btree (gid);



CREATE INDEX artist_alias_idx_artist ON musicbrainz.artist_alias USING btree (artist);



CREATE UNIQUE INDEX artist_alias_idx_primary ON musicbrainz.artist_alias USING btree (artist, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE UNIQUE INDEX artist_alias_type_idx_gid ON musicbrainz.artist_alias_type USING btree (gid);



CREATE INDEX artist_attribute_idx_artist ON musicbrainz.artist_attribute USING btree (artist);



CREATE UNIQUE INDEX artist_attribute_type_allowed_value_idx_gid ON musicbrainz.artist_attribute_type_allowed_value USING btree (gid);



CREATE INDEX artist_attribute_type_allowed_value_idx_name ON musicbrainz.artist_attribute_type_allowed_value USING btree (artist_attribute_type);



CREATE UNIQUE INDEX artist_attribute_type_idx_gid ON musicbrainz.artist_attribute_type USING btree (gid);



CREATE INDEX artist_credit_name_idx_artist ON musicbrainz.artist_credit_name USING btree (artist);



CREATE INDEX artist_gid_redirect_idx_new_id ON musicbrainz.artist_gid_redirect USING btree (new_id);



CREATE INDEX artist_idx_area ON musicbrainz.artist USING btree (area);



CREATE INDEX artist_idx_begin_area ON musicbrainz.artist USING btree (begin_area);



CREATE INDEX artist_idx_end_area ON musicbrainz.artist USING btree (end_area);



CREATE UNIQUE INDEX artist_idx_gid ON musicbrainz.artist USING btree (gid);



CREATE INDEX artist_idx_lower_name ON musicbrainz.artist USING btree (lower((name)::text));



CREATE INDEX artist_idx_name ON musicbrainz.artist USING btree (name);



CREATE UNIQUE INDEX artist_idx_null_comment ON musicbrainz.artist USING btree (name) WHERE (comment IS NULL);



CREATE INDEX artist_idx_sort_name ON musicbrainz.artist USING btree (sort_name);



CREATE UNIQUE INDEX artist_idx_uniq_name_comment ON musicbrainz.artist USING btree (name, comment) WHERE (comment IS NOT NULL);



CREATE INDEX artist_rating_raw_idx_artist ON musicbrainz.artist_rating_raw USING btree (artist);



CREATE INDEX artist_rating_raw_idx_editor ON musicbrainz.artist_rating_raw USING btree (editor);



CREATE INDEX artist_tag_idx_tag ON musicbrainz.artist_tag USING btree (tag);



CREATE INDEX artist_tag_raw_idx_editor ON musicbrainz.artist_tag_raw USING btree (editor);



CREATE INDEX artist_tag_raw_idx_tag ON musicbrainz.artist_tag_raw USING btree (tag);



CREATE UNIQUE INDEX artist_type_idx_gid ON musicbrainz.artist_type USING btree (gid);



CREATE UNIQUE INDEX cdtoc_idx_discid ON musicbrainz.cdtoc USING btree (discid);



CREATE INDEX cdtoc_idx_freedb_id ON musicbrainz.cdtoc USING btree (freedb_id);



CREATE INDEX cdtoc_raw_discid ON musicbrainz.cdtoc_raw USING btree (discid);



CREATE UNIQUE INDEX cdtoc_raw_toc ON musicbrainz.cdtoc_raw USING btree (track_count, leadout_offset, track_offset);



CREATE INDEX cdtoc_raw_track_offset ON musicbrainz.cdtoc_raw USING btree (track_offset);



CREATE INDEX edit_area_idx ON musicbrainz.edit_area USING btree (area);



CREATE INDEX edit_artist_idx ON musicbrainz.edit_artist USING btree (artist);



CREATE INDEX edit_artist_idx_status ON musicbrainz.edit_artist USING btree (status);



CREATE INDEX edit_data_idx_link_type ON musicbrainz.edit_data USING gin (array_remove(ARRAY[((data #>> '{link_type,id}'::text[]))::integer, ((data #>> '{link,link_type,id}'::text[]))::integer, ((data #>> '{old,link_type,id}'::text[]))::integer, ((data #>> '{new,link_type,id}'::text[]))::integer, ((data #>> '{relationship,link_type,id}'::text[]))::integer], NULL::integer));



CREATE INDEX edit_event_idx ON musicbrainz.edit_event USING btree (event);



CREATE INDEX edit_idx_close_time ON musicbrainz.edit USING brin (close_time);



CREATE INDEX edit_idx_editor_id_desc ON musicbrainz.edit USING btree (editor, id DESC);



CREATE INDEX edit_idx_editor_open_time ON musicbrainz.edit USING btree (editor, open_time);



CREATE INDEX edit_idx_expire_time ON musicbrainz.edit USING brin (expire_time);



CREATE INDEX edit_idx_open_time ON musicbrainz.edit USING brin (open_time);



CREATE INDEX edit_idx_status_id ON musicbrainz.edit USING btree (status, id) WHERE (status <> 2);



CREATE INDEX edit_idx_type_id ON musicbrainz.edit USING btree (type, id);



CREATE INDEX edit_instrument_idx ON musicbrainz.edit_instrument USING btree (instrument);



CREATE INDEX edit_label_idx ON musicbrainz.edit_label USING btree (label);



CREATE INDEX edit_label_idx_status ON musicbrainz.edit_label USING btree (status);



CREATE INDEX edit_note_idx_edit ON musicbrainz.edit_note USING btree (edit);



CREATE INDEX edit_note_idx_editor ON musicbrainz.edit_note USING btree (editor);



CREATE INDEX edit_note_idx_post_time ON musicbrainz.edit_note USING brin (post_time);



CREATE INDEX edit_note_idx_post_time_edit ON musicbrainz.edit_note USING btree (post_time DESC NULLS LAST, edit DESC);



CREATE INDEX edit_note_recipient_idx_recipient ON musicbrainz.edit_note_recipient USING btree (recipient);



CREATE INDEX edit_place_idx ON musicbrainz.edit_place USING btree (place);



CREATE INDEX edit_recording_idx ON musicbrainz.edit_recording USING btree (recording);



CREATE INDEX edit_release_group_idx ON musicbrainz.edit_release_group USING btree (release_group);



CREATE INDEX edit_release_idx ON musicbrainz.edit_release USING btree (release);



CREATE INDEX edit_series_idx ON musicbrainz.edit_series USING btree (series);



CREATE INDEX edit_url_idx ON musicbrainz.edit_url USING btree (url);



CREATE INDEX edit_work_idx ON musicbrainz.edit_work USING btree (work);



CREATE INDEX editor_collection_idx_editor ON musicbrainz.editor_collection USING btree (editor);



CREATE UNIQUE INDEX editor_collection_idx_gid ON musicbrainz.editor_collection USING btree (gid);



CREATE INDEX editor_collection_idx_name ON musicbrainz.editor_collection USING btree (name);



CREATE UNIQUE INDEX editor_collection_type_idx_gid ON musicbrainz.editor_collection_type USING btree (gid);



CREATE UNIQUE INDEX editor_idx_name ON musicbrainz.editor USING btree (lower((name)::text));



CREATE INDEX editor_language_idx_language ON musicbrainz.editor_language USING btree (language);



CREATE UNIQUE INDEX editor_oauth_token_idx_access_token ON musicbrainz.editor_oauth_token USING btree (access_token);



CREATE INDEX editor_oauth_token_idx_editor ON musicbrainz.editor_oauth_token USING btree (editor);



CREATE UNIQUE INDEX editor_oauth_token_idx_refresh_token ON musicbrainz.editor_oauth_token USING btree (refresh_token);



CREATE UNIQUE INDEX editor_preference_idx_editor_name ON musicbrainz.editor_preference USING btree (editor, name);



CREATE INDEX editor_subscribe_artist_idx_artist ON musicbrainz.editor_subscribe_artist USING btree (artist);



CREATE UNIQUE INDEX editor_subscribe_artist_idx_uniq ON musicbrainz.editor_subscribe_artist USING btree (editor, artist);



CREATE INDEX editor_subscribe_collection_idx_collection ON musicbrainz.editor_subscribe_collection USING btree (collection);



CREATE UNIQUE INDEX editor_subscribe_collection_idx_uniq ON musicbrainz.editor_subscribe_collection USING btree (editor, collection);



CREATE UNIQUE INDEX editor_subscribe_editor_idx_uniq ON musicbrainz.editor_subscribe_editor USING btree (editor, subscribed_editor);



CREATE INDEX editor_subscribe_label_idx_label ON musicbrainz.editor_subscribe_label USING btree (label);



CREATE UNIQUE INDEX editor_subscribe_label_idx_uniq ON musicbrainz.editor_subscribe_label USING btree (editor, label);



CREATE INDEX editor_subscribe_series_idx_series ON musicbrainz.editor_subscribe_series USING btree (series);



CREATE UNIQUE INDEX editor_subscribe_series_idx_uniq ON musicbrainz.editor_subscribe_series USING btree (editor, series);



CREATE INDEX event_alias_idx_event ON musicbrainz.event_alias USING btree (event);



CREATE UNIQUE INDEX event_alias_idx_primary ON musicbrainz.event_alias USING btree (event, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE UNIQUE INDEX event_alias_type_idx_gid ON musicbrainz.event_alias_type USING btree (gid);



CREATE INDEX event_attribute_idx_event ON musicbrainz.event_attribute USING btree (event);



CREATE UNIQUE INDEX event_attribute_type_allowed_value_idx_gid ON musicbrainz.event_attribute_type_allowed_value USING btree (gid);



CREATE INDEX event_attribute_type_allowed_value_idx_name ON musicbrainz.event_attribute_type_allowed_value USING btree (event_attribute_type);



CREATE UNIQUE INDEX event_attribute_type_idx_gid ON musicbrainz.event_attribute_type USING btree (gid);



CREATE INDEX event_gid_redirect_idx_new_id ON musicbrainz.event_gid_redirect USING btree (new_id);



CREATE UNIQUE INDEX event_idx_gid ON musicbrainz.event USING btree (gid);



CREATE INDEX event_idx_name ON musicbrainz.event USING btree (name);



CREATE INDEX event_rating_raw_idx_editor ON musicbrainz.event_rating_raw USING btree (editor);



CREATE INDEX event_rating_raw_idx_event ON musicbrainz.event_rating_raw USING btree (event);



CREATE INDEX event_tag_idx_tag ON musicbrainz.event_tag USING btree (tag);



CREATE INDEX event_tag_raw_idx_editor ON musicbrainz.event_tag_raw USING btree (editor);



CREATE INDEX event_tag_raw_idx_tag ON musicbrainz.event_tag_raw USING btree (tag);



CREATE UNIQUE INDEX event_type_idx_gid ON musicbrainz.event_type USING btree (gid);



CREATE UNIQUE INDEX gender_idx_gid ON musicbrainz.gender USING btree (gid);



CREATE INDEX genre_alias_idx_genre ON musicbrainz.genre_alias USING btree (genre);



CREATE UNIQUE INDEX genre_alias_idx_primary ON musicbrainz.genre_alias USING btree (genre, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE UNIQUE INDEX genre_idx_gid ON musicbrainz.genre USING btree (gid);



CREATE UNIQUE INDEX genre_idx_name ON musicbrainz.genre USING btree (lower((name)::text));



CREATE INDEX instrument_alias_idx_instrument ON musicbrainz.instrument_alias USING btree (instrument);



CREATE UNIQUE INDEX instrument_alias_idx_primary ON musicbrainz.instrument_alias USING btree (instrument, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE UNIQUE INDEX instrument_alias_type_idx_gid ON musicbrainz.instrument_alias_type USING btree (gid);



CREATE INDEX instrument_attribute_idx_instrument ON musicbrainz.instrument_attribute USING btree (instrument);



CREATE UNIQUE INDEX instrument_attribute_type_allowed_value_idx_gid ON musicbrainz.instrument_attribute_type_allowed_value USING btree (gid);



CREATE INDEX instrument_attribute_type_allowed_value_idx_name ON musicbrainz.instrument_attribute_type_allowed_value USING btree (instrument_attribute_type);



CREATE UNIQUE INDEX instrument_attribute_type_idx_gid ON musicbrainz.instrument_attribute_type USING btree (gid);



CREATE INDEX instrument_gid_redirect_idx_new_id ON musicbrainz.instrument_gid_redirect USING btree (new_id);



CREATE UNIQUE INDEX instrument_idx_gid ON musicbrainz.instrument USING btree (gid);



CREATE INDEX instrument_idx_name ON musicbrainz.instrument USING btree (name);



CREATE INDEX instrument_tag_idx_tag ON musicbrainz.instrument_tag USING btree (tag);



CREATE INDEX instrument_tag_raw_idx_editor ON musicbrainz.instrument_tag_raw USING btree (editor);



CREATE INDEX instrument_tag_raw_idx_instrument ON musicbrainz.instrument_tag_raw USING btree (instrument);



CREATE INDEX instrument_tag_raw_idx_tag ON musicbrainz.instrument_tag_raw USING btree (tag);



CREATE UNIQUE INDEX instrument_type_idx_gid ON musicbrainz.instrument_type USING btree (gid);



CREATE INDEX iso_3166_1_idx_area ON musicbrainz.iso_3166_1 USING btree (area);



CREATE INDEX iso_3166_2_idx_area ON musicbrainz.iso_3166_2 USING btree (area);



CREATE INDEX iso_3166_3_idx_area ON musicbrainz.iso_3166_3 USING btree (area);



CREATE INDEX isrc_idx_isrc ON musicbrainz.isrc USING btree (isrc);



CREATE UNIQUE INDEX isrc_idx_isrc_recording ON musicbrainz.isrc USING btree (isrc, recording);



CREATE INDEX isrc_idx_recording ON musicbrainz.isrc USING btree (recording);



CREATE UNIQUE INDEX iswc_idx_iswc ON musicbrainz.iswc USING btree (iswc, work);



CREATE INDEX iswc_idx_work ON musicbrainz.iswc USING btree (work);



CREATE INDEX l_area_area_idx_entity1 ON musicbrainz.l_area_area USING btree (entity1);



CREATE UNIQUE INDEX l_area_area_idx_uniq ON musicbrainz.l_area_area USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_area_artist_idx_entity1 ON musicbrainz.l_area_artist USING btree (entity1);



CREATE UNIQUE INDEX l_area_artist_idx_uniq ON musicbrainz.l_area_artist USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_area_event_idx_entity1 ON musicbrainz.l_area_event USING btree (entity1);



CREATE UNIQUE INDEX l_area_event_idx_uniq ON musicbrainz.l_area_event USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_area_instrument_idx_entity1 ON musicbrainz.l_area_instrument USING btree (entity1);



CREATE UNIQUE INDEX l_area_instrument_idx_uniq ON musicbrainz.l_area_instrument USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_area_label_idx_entity1 ON musicbrainz.l_area_label USING btree (entity1);



CREATE UNIQUE INDEX l_area_label_idx_uniq ON musicbrainz.l_area_label USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_area_place_idx_entity1 ON musicbrainz.l_area_place USING btree (entity1);



CREATE UNIQUE INDEX l_area_place_idx_uniq ON musicbrainz.l_area_place USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_area_recording_idx_entity1 ON musicbrainz.l_area_recording USING btree (entity1);



CREATE UNIQUE INDEX l_area_recording_idx_uniq ON musicbrainz.l_area_recording USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_area_release_group_idx_entity1 ON musicbrainz.l_area_release_group USING btree (entity1);



CREATE UNIQUE INDEX l_area_release_group_idx_uniq ON musicbrainz.l_area_release_group USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_area_release_idx_entity1 ON musicbrainz.l_area_release USING btree (entity1);



CREATE UNIQUE INDEX l_area_release_idx_uniq ON musicbrainz.l_area_release USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_area_series_idx_entity1 ON musicbrainz.l_area_series USING btree (entity1);



CREATE UNIQUE INDEX l_area_series_idx_uniq ON musicbrainz.l_area_series USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_area_url_idx_entity1 ON musicbrainz.l_area_url USING btree (entity1);



CREATE UNIQUE INDEX l_area_url_idx_uniq ON musicbrainz.l_area_url USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_area_work_idx_entity1 ON musicbrainz.l_area_work USING btree (entity1);



CREATE UNIQUE INDEX l_area_work_idx_uniq ON musicbrainz.l_area_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_artist_artist_idx_entity1 ON musicbrainz.l_artist_artist USING btree (entity1);



CREATE UNIQUE INDEX l_artist_artist_idx_uniq ON musicbrainz.l_artist_artist USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_artist_event_idx_entity1 ON musicbrainz.l_artist_event USING btree (entity1);



CREATE UNIQUE INDEX l_artist_event_idx_uniq ON musicbrainz.l_artist_event USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_artist_instrument_idx_entity1 ON musicbrainz.l_artist_instrument USING btree (entity1);



CREATE UNIQUE INDEX l_artist_instrument_idx_uniq ON musicbrainz.l_artist_instrument USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_artist_label_idx_entity1 ON musicbrainz.l_artist_label USING btree (entity1);



CREATE UNIQUE INDEX l_artist_label_idx_uniq ON musicbrainz.l_artist_label USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_artist_place_idx_entity1 ON musicbrainz.l_artist_place USING btree (entity1);



CREATE UNIQUE INDEX l_artist_place_idx_uniq ON musicbrainz.l_artist_place USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_artist_recording_idx_entity1 ON musicbrainz.l_artist_recording USING btree (entity1);



CREATE UNIQUE INDEX l_artist_recording_idx_uniq ON musicbrainz.l_artist_recording USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_artist_release_group_idx_entity1 ON musicbrainz.l_artist_release_group USING btree (entity1);



CREATE UNIQUE INDEX l_artist_release_group_idx_uniq ON musicbrainz.l_artist_release_group USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_artist_release_idx_entity1 ON musicbrainz.l_artist_release USING btree (entity1);



CREATE UNIQUE INDEX l_artist_release_idx_uniq ON musicbrainz.l_artist_release USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_artist_series_idx_entity1 ON musicbrainz.l_artist_series USING btree (entity1);



CREATE UNIQUE INDEX l_artist_series_idx_uniq ON musicbrainz.l_artist_series USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_artist_url_idx_entity1 ON musicbrainz.l_artist_url USING btree (entity1);



CREATE UNIQUE INDEX l_artist_url_idx_uniq ON musicbrainz.l_artist_url USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_artist_work_idx_entity1 ON musicbrainz.l_artist_work USING btree (entity1);



CREATE UNIQUE INDEX l_artist_work_idx_uniq ON musicbrainz.l_artist_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_event_event_idx_entity1 ON musicbrainz.l_event_event USING btree (entity1);



CREATE UNIQUE INDEX l_event_event_idx_uniq ON musicbrainz.l_event_event USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_event_instrument_idx_entity1 ON musicbrainz.l_event_instrument USING btree (entity1);



CREATE UNIQUE INDEX l_event_instrument_idx_uniq ON musicbrainz.l_event_instrument USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_event_label_idx_entity1 ON musicbrainz.l_event_label USING btree (entity1);



CREATE UNIQUE INDEX l_event_label_idx_uniq ON musicbrainz.l_event_label USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_event_place_idx_entity1 ON musicbrainz.l_event_place USING btree (entity1);



CREATE UNIQUE INDEX l_event_place_idx_uniq ON musicbrainz.l_event_place USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_event_recording_idx_entity1 ON musicbrainz.l_event_recording USING btree (entity1);



CREATE UNIQUE INDEX l_event_recording_idx_uniq ON musicbrainz.l_event_recording USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_event_release_group_idx_entity1 ON musicbrainz.l_event_release_group USING btree (entity1);



CREATE UNIQUE INDEX l_event_release_group_idx_uniq ON musicbrainz.l_event_release_group USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_event_release_idx_entity1 ON musicbrainz.l_event_release USING btree (entity1);



CREATE UNIQUE INDEX l_event_release_idx_uniq ON musicbrainz.l_event_release USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_event_series_idx_entity1 ON musicbrainz.l_event_series USING btree (entity1);



CREATE UNIQUE INDEX l_event_series_idx_uniq ON musicbrainz.l_event_series USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_event_url_idx_entity1 ON musicbrainz.l_event_url USING btree (entity1);



CREATE UNIQUE INDEX l_event_url_idx_uniq ON musicbrainz.l_event_url USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_event_work_idx_entity1 ON musicbrainz.l_event_work USING btree (entity1);



CREATE UNIQUE INDEX l_event_work_idx_uniq ON musicbrainz.l_event_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_instrument_instrument_idx_entity1 ON musicbrainz.l_instrument_instrument USING btree (entity1);



CREATE UNIQUE INDEX l_instrument_instrument_idx_uniq ON musicbrainz.l_instrument_instrument USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_instrument_label_idx_entity1 ON musicbrainz.l_instrument_label USING btree (entity1);



CREATE UNIQUE INDEX l_instrument_label_idx_uniq ON musicbrainz.l_instrument_label USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_instrument_place_idx_entity1 ON musicbrainz.l_instrument_place USING btree (entity1);



CREATE UNIQUE INDEX l_instrument_place_idx_uniq ON musicbrainz.l_instrument_place USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_instrument_recording_idx_entity1 ON musicbrainz.l_instrument_recording USING btree (entity1);



CREATE UNIQUE INDEX l_instrument_recording_idx_uniq ON musicbrainz.l_instrument_recording USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_instrument_release_group_idx_entity1 ON musicbrainz.l_instrument_release_group USING btree (entity1);



CREATE UNIQUE INDEX l_instrument_release_group_idx_uniq ON musicbrainz.l_instrument_release_group USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_instrument_release_idx_entity1 ON musicbrainz.l_instrument_release USING btree (entity1);



CREATE UNIQUE INDEX l_instrument_release_idx_uniq ON musicbrainz.l_instrument_release USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_instrument_series_idx_entity1 ON musicbrainz.l_instrument_series USING btree (entity1);



CREATE UNIQUE INDEX l_instrument_series_idx_uniq ON musicbrainz.l_instrument_series USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_instrument_url_idx_entity1 ON musicbrainz.l_instrument_url USING btree (entity1);



CREATE UNIQUE INDEX l_instrument_url_idx_uniq ON musicbrainz.l_instrument_url USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_instrument_work_idx_entity1 ON musicbrainz.l_instrument_work USING btree (entity1);



CREATE UNIQUE INDEX l_instrument_work_idx_uniq ON musicbrainz.l_instrument_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_label_label_idx_entity1 ON musicbrainz.l_label_label USING btree (entity1);



CREATE UNIQUE INDEX l_label_label_idx_uniq ON musicbrainz.l_label_label USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_label_place_idx_entity1 ON musicbrainz.l_label_place USING btree (entity1);



CREATE UNIQUE INDEX l_label_place_idx_uniq ON musicbrainz.l_label_place USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_label_recording_idx_entity1 ON musicbrainz.l_label_recording USING btree (entity1);



CREATE UNIQUE INDEX l_label_recording_idx_uniq ON musicbrainz.l_label_recording USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_label_release_group_idx_entity1 ON musicbrainz.l_label_release_group USING btree (entity1);



CREATE UNIQUE INDEX l_label_release_group_idx_uniq ON musicbrainz.l_label_release_group USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_label_release_idx_entity1 ON musicbrainz.l_label_release USING btree (entity1);



CREATE UNIQUE INDEX l_label_release_idx_uniq ON musicbrainz.l_label_release USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_label_series_idx_entity1 ON musicbrainz.l_label_series USING btree (entity1);



CREATE UNIQUE INDEX l_label_series_idx_uniq ON musicbrainz.l_label_series USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_label_url_idx_entity1 ON musicbrainz.l_label_url USING btree (entity1);



CREATE UNIQUE INDEX l_label_url_idx_uniq ON musicbrainz.l_label_url USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_label_work_idx_entity1 ON musicbrainz.l_label_work USING btree (entity1);



CREATE UNIQUE INDEX l_label_work_idx_uniq ON musicbrainz.l_label_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_place_place_idx_entity1 ON musicbrainz.l_place_place USING btree (entity1);



CREATE UNIQUE INDEX l_place_place_idx_uniq ON musicbrainz.l_place_place USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_place_recording_idx_entity1 ON musicbrainz.l_place_recording USING btree (entity1);



CREATE UNIQUE INDEX l_place_recording_idx_uniq ON musicbrainz.l_place_recording USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_place_release_group_idx_entity1 ON musicbrainz.l_place_release_group USING btree (entity1);



CREATE UNIQUE INDEX l_place_release_group_idx_uniq ON musicbrainz.l_place_release_group USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_place_release_idx_entity1 ON musicbrainz.l_place_release USING btree (entity1);



CREATE UNIQUE INDEX l_place_release_idx_uniq ON musicbrainz.l_place_release USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_place_series_idx_entity1 ON musicbrainz.l_place_series USING btree (entity1);



CREATE UNIQUE INDEX l_place_series_idx_uniq ON musicbrainz.l_place_series USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_place_url_idx_entity1 ON musicbrainz.l_place_url USING btree (entity1);



CREATE UNIQUE INDEX l_place_url_idx_uniq ON musicbrainz.l_place_url USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_place_work_idx_entity1 ON musicbrainz.l_place_work USING btree (entity1);



CREATE UNIQUE INDEX l_place_work_idx_uniq ON musicbrainz.l_place_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_recording_recording_idx_entity1 ON musicbrainz.l_recording_recording USING btree (entity1);



CREATE UNIQUE INDEX l_recording_recording_idx_uniq ON musicbrainz.l_recording_recording USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_recording_release_group_idx_entity1 ON musicbrainz.l_recording_release_group USING btree (entity1);



CREATE UNIQUE INDEX l_recording_release_group_idx_uniq ON musicbrainz.l_recording_release_group USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_recording_release_idx_entity1 ON musicbrainz.l_recording_release USING btree (entity1);



CREATE UNIQUE INDEX l_recording_release_idx_uniq ON musicbrainz.l_recording_release USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_recording_series_idx_entity1 ON musicbrainz.l_recording_series USING btree (entity1);



CREATE UNIQUE INDEX l_recording_series_idx_uniq ON musicbrainz.l_recording_series USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_recording_url_idx_entity1 ON musicbrainz.l_recording_url USING btree (entity1);



CREATE UNIQUE INDEX l_recording_url_idx_uniq ON musicbrainz.l_recording_url USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_recording_work_idx_entity1 ON musicbrainz.l_recording_work USING btree (entity1);



CREATE UNIQUE INDEX l_recording_work_idx_uniq ON musicbrainz.l_recording_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_release_group_release_group_idx_entity1 ON musicbrainz.l_release_group_release_group USING btree (entity1);



CREATE UNIQUE INDEX l_release_group_release_group_idx_uniq ON musicbrainz.l_release_group_release_group USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_release_group_series_idx_entity1 ON musicbrainz.l_release_group_series USING btree (entity1);



CREATE UNIQUE INDEX l_release_group_series_idx_uniq ON musicbrainz.l_release_group_series USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_release_group_url_idx_entity1 ON musicbrainz.l_release_group_url USING btree (entity1);



CREATE UNIQUE INDEX l_release_group_url_idx_uniq ON musicbrainz.l_release_group_url USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_release_group_work_idx_entity1 ON musicbrainz.l_release_group_work USING btree (entity1);



CREATE UNIQUE INDEX l_release_group_work_idx_uniq ON musicbrainz.l_release_group_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_release_release_group_idx_entity1 ON musicbrainz.l_release_release_group USING btree (entity1);



CREATE UNIQUE INDEX l_release_release_group_idx_uniq ON musicbrainz.l_release_release_group USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_release_release_idx_entity1 ON musicbrainz.l_release_release USING btree (entity1);



CREATE UNIQUE INDEX l_release_release_idx_uniq ON musicbrainz.l_release_release USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_release_series_idx_entity1 ON musicbrainz.l_release_series USING btree (entity1);



CREATE UNIQUE INDEX l_release_series_idx_uniq ON musicbrainz.l_release_series USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_release_url_idx_entity1 ON musicbrainz.l_release_url USING btree (entity1);



CREATE UNIQUE INDEX l_release_url_idx_uniq ON musicbrainz.l_release_url USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_release_work_idx_entity1 ON musicbrainz.l_release_work USING btree (entity1);



CREATE UNIQUE INDEX l_release_work_idx_uniq ON musicbrainz.l_release_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_series_series_idx_entity1 ON musicbrainz.l_series_series USING btree (entity1);



CREATE UNIQUE INDEX l_series_series_idx_uniq ON musicbrainz.l_series_series USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_series_url_idx_entity1 ON musicbrainz.l_series_url USING btree (entity1);



CREATE UNIQUE INDEX l_series_url_idx_uniq ON musicbrainz.l_series_url USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_series_work_idx_entity1 ON musicbrainz.l_series_work USING btree (entity1);



CREATE UNIQUE INDEX l_series_work_idx_uniq ON musicbrainz.l_series_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_url_url_idx_entity1 ON musicbrainz.l_url_url USING btree (entity1);



CREATE UNIQUE INDEX l_url_url_idx_uniq ON musicbrainz.l_url_url USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_url_work_idx_entity1 ON musicbrainz.l_url_work USING btree (entity1);



CREATE UNIQUE INDEX l_url_work_idx_uniq ON musicbrainz.l_url_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX l_work_work_idx_entity1 ON musicbrainz.l_work_work USING btree (entity1);



CREATE UNIQUE INDEX l_work_work_idx_uniq ON musicbrainz.l_work_work USING btree (entity0, entity1, link, link_order);



CREATE INDEX label_alias_idx_label ON musicbrainz.label_alias USING btree (label);



CREATE UNIQUE INDEX label_alias_idx_primary ON musicbrainz.label_alias USING btree (label, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE UNIQUE INDEX label_alias_type_idx_gid ON musicbrainz.label_alias_type USING btree (gid);



CREATE INDEX label_attribute_idx_label ON musicbrainz.label_attribute USING btree (label);



CREATE UNIQUE INDEX label_attribute_type_allowed_value_idx_gid ON musicbrainz.label_attribute_type_allowed_value USING btree (gid);



CREATE INDEX label_attribute_type_allowed_value_idx_name ON musicbrainz.label_attribute_type_allowed_value USING btree (label_attribute_type);



CREATE UNIQUE INDEX label_attribute_type_idx_gid ON musicbrainz.label_attribute_type USING btree (gid);



CREATE INDEX label_gid_redirect_idx_new_id ON musicbrainz.label_gid_redirect USING btree (new_id);



CREATE INDEX label_idx_area ON musicbrainz.label USING btree (area);



CREATE UNIQUE INDEX label_idx_gid ON musicbrainz.label USING btree (gid);



CREATE INDEX label_idx_lower_name ON musicbrainz.label USING btree (lower((name)::text));



CREATE INDEX label_idx_name ON musicbrainz.label USING btree (name);



CREATE UNIQUE INDEX label_idx_null_comment ON musicbrainz.label USING btree (name) WHERE (comment IS NULL);



CREATE UNIQUE INDEX label_idx_uniq_name_comment ON musicbrainz.label USING btree (name, comment) WHERE (comment IS NOT NULL);



CREATE INDEX label_rating_raw_idx_editor ON musicbrainz.label_rating_raw USING btree (editor);



CREATE INDEX label_rating_raw_idx_label ON musicbrainz.label_rating_raw USING btree (label);



CREATE INDEX label_tag_idx_tag ON musicbrainz.label_tag USING btree (tag);



CREATE INDEX label_tag_raw_idx_editor ON musicbrainz.label_tag_raw USING btree (editor);



CREATE INDEX label_tag_raw_idx_tag ON musicbrainz.label_tag_raw USING btree (tag);



CREATE UNIQUE INDEX label_type_idx_gid ON musicbrainz.label_type USING btree (gid);



CREATE UNIQUE INDEX language_idx_iso_code_1 ON musicbrainz.language USING btree (iso_code_1);



CREATE UNIQUE INDEX language_idx_iso_code_2b ON musicbrainz.language USING btree (iso_code_2b);



CREATE UNIQUE INDEX language_idx_iso_code_2t ON musicbrainz.language USING btree (iso_code_2t);



CREATE UNIQUE INDEX language_idx_iso_code_3 ON musicbrainz.language USING btree (iso_code_3);



CREATE UNIQUE INDEX link_attribute_type_idx_gid ON musicbrainz.link_attribute_type USING btree (gid);



CREATE INDEX link_idx_type_attr ON musicbrainz.link USING btree (link_type, attribute_count);



CREATE UNIQUE INDEX link_type_idx_gid ON musicbrainz.link_type USING btree (gid);



CREATE INDEX medium_attribute_idx_medium ON musicbrainz.medium_attribute USING btree (medium);



CREATE UNIQUE INDEX medium_attribute_type_allowed_value_idx_gid ON musicbrainz.medium_attribute_type_allowed_value USING btree (gid);



CREATE INDEX medium_attribute_type_allowed_value_idx_name ON musicbrainz.medium_attribute_type_allowed_value USING btree (medium_attribute_type);



CREATE UNIQUE INDEX medium_attribute_type_idx_gid ON musicbrainz.medium_attribute_type USING btree (gid);



CREATE INDEX medium_cdtoc_idx_cdtoc ON musicbrainz.medium_cdtoc USING btree (cdtoc);



CREATE INDEX medium_cdtoc_idx_medium ON musicbrainz.medium_cdtoc USING btree (medium);



CREATE UNIQUE INDEX medium_cdtoc_idx_uniq ON musicbrainz.medium_cdtoc USING btree (medium, cdtoc);



CREATE UNIQUE INDEX medium_format_idx_gid ON musicbrainz.medium_format USING btree (gid);



CREATE INDEX medium_idx_release_position ON musicbrainz.medium USING btree (release, "position");



CREATE INDEX medium_idx_track_count ON musicbrainz.medium USING btree (track_count);



CREATE INDEX medium_index_idx ON musicbrainz.medium_index USING gist (toc);



CREATE UNIQUE INDEX old_editor_name_idx_name ON musicbrainz.old_editor_name USING btree (lower((name)::text));



CREATE INDEX place_alias_idx_place ON musicbrainz.place_alias USING btree (place);



CREATE UNIQUE INDEX place_alias_idx_primary ON musicbrainz.place_alias USING btree (place, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE UNIQUE INDEX place_alias_type_idx_gid ON musicbrainz.place_alias_type USING btree (gid);



CREATE INDEX place_attribute_idx_place ON musicbrainz.place_attribute USING btree (place);



CREATE UNIQUE INDEX place_attribute_type_allowed_value_idx_gid ON musicbrainz.place_attribute_type_allowed_value USING btree (gid);



CREATE INDEX place_attribute_type_allowed_value_idx_name ON musicbrainz.place_attribute_type_allowed_value USING btree (place_attribute_type);



CREATE UNIQUE INDEX place_attribute_type_idx_gid ON musicbrainz.place_attribute_type USING btree (gid);



CREATE INDEX place_gid_redirect_idx_new_id ON musicbrainz.place_gid_redirect USING btree (new_id);



CREATE INDEX place_idx_area ON musicbrainz.place USING btree (area);



CREATE INDEX place_idx_geo ON musicbrainz.place USING gist (public.ll_to_earth(coordinates[0], coordinates[1])) WHERE (coordinates IS NOT NULL);



CREATE UNIQUE INDEX place_idx_gid ON musicbrainz.place USING btree (gid);



CREATE INDEX place_idx_name ON musicbrainz.place USING btree (name);



CREATE INDEX place_tag_idx_tag ON musicbrainz.place_tag USING btree (tag);



CREATE INDEX place_tag_raw_idx_editor ON musicbrainz.place_tag_raw USING btree (editor);



CREATE INDEX place_tag_raw_idx_tag ON musicbrainz.place_tag_raw USING btree (tag);



CREATE UNIQUE INDEX place_type_idx_gid ON musicbrainz.place_type USING btree (gid);



CREATE UNIQUE INDEX recording_alias_idx_primary ON musicbrainz.recording_alias USING btree (recording, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE INDEX recording_alias_idx_recording ON musicbrainz.recording_alias USING btree (recording);



CREATE UNIQUE INDEX recording_alias_type_idx_gid ON musicbrainz.recording_alias_type USING btree (gid);



CREATE INDEX recording_attribute_idx_recording ON musicbrainz.recording_attribute USING btree (recording);



CREATE UNIQUE INDEX recording_attribute_type_allowed_value_idx_gid ON musicbrainz.recording_attribute_type_allowed_value USING btree (gid);



CREATE INDEX recording_attribute_type_allowed_value_idx_name ON musicbrainz.recording_attribute_type_allowed_value USING btree (recording_attribute_type);



CREATE UNIQUE INDEX recording_attribute_type_idx_gid ON musicbrainz.recording_attribute_type USING btree (gid);



CREATE INDEX recording_gid_redirect_idx_new_id ON musicbrainz.recording_gid_redirect USING btree (new_id);



CREATE INDEX recording_idx_artist_credit ON musicbrainz.recording USING btree (artist_credit);



CREATE UNIQUE INDEX recording_idx_gid ON musicbrainz.recording USING btree (gid);



CREATE INDEX recording_idx_name ON musicbrainz.recording USING btree (name);



CREATE INDEX recording_rating_raw_idx_editor ON musicbrainz.recording_rating_raw USING btree (editor);



CREATE INDEX recording_tag_idx_tag ON musicbrainz.recording_tag USING btree (tag);



CREATE INDEX recording_tag_raw_idx_editor ON musicbrainz.recording_tag_raw USING btree (editor);



CREATE INDEX recording_tag_raw_idx_tag ON musicbrainz.recording_tag_raw USING btree (tag);



CREATE INDEX recording_tag_raw_idx_track ON musicbrainz.recording_tag_raw USING btree (recording);



CREATE UNIQUE INDEX release_alias_idx_primary ON musicbrainz.release_alias USING btree (release, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE INDEX release_alias_idx_release ON musicbrainz.release_alias USING btree (release);



CREATE INDEX release_attribute_idx_release ON musicbrainz.release_attribute USING btree (release);



CREATE UNIQUE INDEX release_attribute_type_allowed_value_idx_gid ON musicbrainz.release_attribute_type_allowed_value USING btree (gid);



CREATE INDEX release_attribute_type_allowed_value_idx_name ON musicbrainz.release_attribute_type_allowed_value USING btree (release_attribute_type);



CREATE UNIQUE INDEX release_attribute_type_idx_gid ON musicbrainz.release_attribute_type USING btree (gid);



CREATE INDEX release_country_idx_country ON musicbrainz.release_country USING btree (country);



CREATE INDEX release_gid_redirect_idx_new_id ON musicbrainz.release_gid_redirect USING btree (new_id);



CREATE UNIQUE INDEX release_group_alias_idx_primary ON musicbrainz.release_group_alias USING btree (release_group, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE INDEX release_group_alias_idx_release_group ON musicbrainz.release_group_alias USING btree (release_group);



CREATE UNIQUE INDEX release_group_alias_type_idx_gid ON musicbrainz.release_group_alias_type USING btree (gid);



CREATE INDEX release_group_attribute_idx_release_group ON musicbrainz.release_group_attribute USING btree (release_group);



CREATE UNIQUE INDEX release_group_attribute_type_allowed_value_idx_gid ON musicbrainz.release_group_attribute_type_allowed_value USING btree (gid);



CREATE INDEX release_group_attribute_type_allowed_value_idx_name ON musicbrainz.release_group_attribute_type_allowed_value USING btree (release_group_attribute_type);



CREATE UNIQUE INDEX release_group_attribute_type_idx_gid ON musicbrainz.release_group_attribute_type USING btree (gid);



CREATE INDEX release_group_gid_redirect_idx_new_id ON musicbrainz.release_group_gid_redirect USING btree (new_id);



CREATE INDEX release_group_idx_artist_credit ON musicbrainz.release_group USING btree (artist_credit);



CREATE UNIQUE INDEX release_group_idx_gid ON musicbrainz.release_group USING btree (gid);



CREATE INDEX release_group_idx_name ON musicbrainz.release_group USING btree (name);



CREATE UNIQUE INDEX release_group_primary_type_idx_gid ON musicbrainz.release_group_primary_type USING btree (gid);



CREATE INDEX release_group_rating_raw_idx_editor ON musicbrainz.release_group_rating_raw USING btree (editor);



CREATE INDEX release_group_rating_raw_idx_release_group ON musicbrainz.release_group_rating_raw USING btree (release_group);



CREATE UNIQUE INDEX release_group_secondary_type_idx_gid ON musicbrainz.release_group_secondary_type USING btree (gid);



CREATE INDEX release_group_tag_idx_tag ON musicbrainz.release_group_tag USING btree (tag);



CREATE INDEX release_group_tag_raw_idx_editor ON musicbrainz.release_group_tag_raw USING btree (editor);



CREATE INDEX release_group_tag_raw_idx_tag ON musicbrainz.release_group_tag_raw USING btree (tag);



CREATE INDEX release_idx_artist_credit ON musicbrainz.release USING btree (artist_credit);



CREATE UNIQUE INDEX release_idx_gid ON musicbrainz.release USING btree (gid);



CREATE INDEX release_idx_name ON musicbrainz.release USING btree (name);



CREATE INDEX release_idx_release_group ON musicbrainz.release USING btree (release_group);



CREATE INDEX release_label_idx_label ON musicbrainz.release_label USING btree (label);



CREATE INDEX release_label_idx_release ON musicbrainz.release_label USING btree (release);



CREATE UNIQUE INDEX release_packaging_idx_gid ON musicbrainz.release_packaging USING btree (gid);



CREATE INDEX release_raw_idx_last_modified ON musicbrainz.release_raw USING btree (last_modified);



CREATE INDEX release_raw_idx_lookup_count ON musicbrainz.release_raw USING btree (lookup_count);



CREATE INDEX release_raw_idx_modify_count ON musicbrainz.release_raw USING btree (modify_count);



CREATE UNIQUE INDEX release_status_idx_gid ON musicbrainz.release_status USING btree (gid);



CREATE INDEX release_tag_idx_tag ON musicbrainz.release_tag USING btree (tag);



CREATE INDEX release_tag_raw_idx_editor ON musicbrainz.release_tag_raw USING btree (editor);



CREATE INDEX release_tag_raw_idx_tag ON musicbrainz.release_tag_raw USING btree (tag);



CREATE UNIQUE INDEX script_idx_iso_code ON musicbrainz.script USING btree (iso_code);



CREATE UNIQUE INDEX series_alias_idx_primary ON musicbrainz.series_alias USING btree (series, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE INDEX series_alias_idx_series ON musicbrainz.series_alias USING btree (series);



CREATE UNIQUE INDEX series_alias_type_idx_gid ON musicbrainz.series_alias_type USING btree (gid);



CREATE INDEX series_attribute_idx_series ON musicbrainz.series_attribute USING btree (series);



CREATE UNIQUE INDEX series_attribute_type_allowed_value_idx_gid ON musicbrainz.series_attribute_type_allowed_value USING btree (gid);



CREATE INDEX series_attribute_type_allowed_value_idx_name ON musicbrainz.series_attribute_type_allowed_value USING btree (series_attribute_type);



CREATE UNIQUE INDEX series_attribute_type_idx_gid ON musicbrainz.series_attribute_type USING btree (gid);



CREATE INDEX series_gid_redirect_idx_new_id ON musicbrainz.series_gid_redirect USING btree (new_id);



CREATE UNIQUE INDEX series_idx_gid ON musicbrainz.series USING btree (gid);



CREATE INDEX series_idx_name ON musicbrainz.series USING btree (name);



CREATE UNIQUE INDEX series_ordering_type_idx_gid ON musicbrainz.series_ordering_type USING btree (gid);



CREATE INDEX series_tag_idx_tag ON musicbrainz.series_tag USING btree (tag);



CREATE INDEX series_tag_raw_idx_editor ON musicbrainz.series_tag_raw USING btree (editor);



CREATE INDEX series_tag_raw_idx_series ON musicbrainz.series_tag_raw USING btree (series);



CREATE INDEX series_tag_raw_idx_tag ON musicbrainz.series_tag_raw USING btree (tag);



CREATE UNIQUE INDEX series_type_idx_gid ON musicbrainz.series_type USING btree (gid);



CREATE UNIQUE INDEX tag_idx_name ON musicbrainz.tag USING btree (name);



CREATE INDEX track_gid_redirect_idx_new_id ON musicbrainz.track_gid_redirect USING btree (new_id);



CREATE INDEX track_idx_artist_credit ON musicbrainz.track USING btree (artist_credit);



CREATE UNIQUE INDEX track_idx_gid ON musicbrainz.track USING btree (gid);



CREATE INDEX track_idx_medium_position ON musicbrainz.track USING btree (medium, "position");



CREATE INDEX track_idx_name ON musicbrainz.track USING btree (name);



CREATE INDEX track_idx_recording ON musicbrainz.track USING btree (recording);



CREATE INDEX track_raw_idx_release ON musicbrainz.track_raw USING btree (release);



CREATE INDEX url_gid_redirect_idx_new_id ON musicbrainz.url_gid_redirect USING btree (new_id);



CREATE UNIQUE INDEX url_idx_gid ON musicbrainz.url USING btree (gid);



CREATE UNIQUE INDEX url_idx_url ON musicbrainz.url USING btree (url);



CREATE INDEX vote_idx_edit ON musicbrainz.vote USING btree (edit);



CREATE INDEX vote_idx_editor_edit ON musicbrainz.vote USING btree (editor, edit) WHERE (superseded = false);



CREATE INDEX vote_idx_editor_vote_time ON musicbrainz.vote USING btree (editor, vote_time);



CREATE INDEX vote_idx_vote_time ON musicbrainz.vote USING brin (vote_time);



CREATE UNIQUE INDEX work_alias_idx_primary ON musicbrainz.work_alias USING btree (work, locale) WHERE ((primary_for_locale = true) AND (locale IS NOT NULL));



CREATE INDEX work_alias_idx_work ON musicbrainz.work_alias USING btree (work);



CREATE UNIQUE INDEX work_alias_type_idx_gid ON musicbrainz.work_alias_type USING btree (gid);



CREATE INDEX work_attribute_idx_work ON musicbrainz.work_attribute USING btree (work);



CREATE UNIQUE INDEX work_attribute_type_allowed_value_idx_gid ON musicbrainz.work_attribute_type_allowed_value USING btree (gid);



CREATE INDEX work_attribute_type_allowed_value_idx_name ON musicbrainz.work_attribute_type_allowed_value USING btree (work_attribute_type);



CREATE UNIQUE INDEX work_attribute_type_idx_gid ON musicbrainz.work_attribute_type USING btree (gid);



CREATE INDEX work_gid_redirect_idx_new_id ON musicbrainz.work_gid_redirect USING btree (new_id);



CREATE UNIQUE INDEX work_idx_gid ON musicbrainz.work USING btree (gid);



CREATE INDEX work_idx_name ON musicbrainz.work USING btree (name);



CREATE INDEX work_tag_idx_tag ON musicbrainz.work_tag USING btree (tag);



CREATE INDEX work_tag_raw_idx_tag ON musicbrainz.work_tag_raw USING btree (tag);



CREATE UNIQUE INDEX work_type_idx_gid ON musicbrainz.work_type USING btree (gid);



CREATE INDEX statistic_name ON statistics.statistic USING btree (name);



CREATE UNIQUE INDEX statistic_name_date_collected ON statistics.statistic USING btree (name, date_collected);



