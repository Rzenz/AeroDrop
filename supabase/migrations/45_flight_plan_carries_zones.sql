-- ============================================================================
-- 45_flight_plan_carries_zones.sql
--
-- Adds the delivery zone and the active no-fly zones to the flight plan, so
-- the exported JSON is everything the drone side needs.
--
-- WHY
-- order_to_mission.py has to refuse a mission whose drop-off is outside the
-- delivery area or inside a no-fly zone. Without this it would need Supabase
-- credentials on the operator's laptop to look them up. With it, the file an
-- administrator downloads is self-contained: the script reads one JSON and
-- checks everything, offline.
--
-- It also means the file records the zones AS THEY WERE when the plan was
-- made, which is what you want if anyone ever asks why a flight was allowed.
--
-- Two new top-level keys. Nothing existing changes shape, so anything already
-- reading this function keeps working.
--
-- The plan's _notes also said "public.no_fly_zones is empty", which stops
-- being true the moment a zone is drawn and would sit beside a non-empty
-- no_fly_zones list in the same file. That sentence is reworded here too;
-- only its text changes, not the shape of _notes.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-44:
--   public.delivery_zone_info()     (39, amended by 41)
--   public.active_no_fly_zones()    (44)
-- ============================================================================

DO $migration$
DECLARE
    v_def text;
    v_old text := '''is_custom_dropoff'', v_custom,';
    v_new text := '''is_custom_dropoff'', v_custom,'
               || E'\n        ''delivery_zone'', public.delivery_zone_info(),'
               || E'\n        ''no_fly_zones'', public.active_no_fly_zones(),';
    -- Text inside a string literal, so no quotes are involved
    v_note_old text := 'No obstacle data exists and public.no_fly_zones is empty. Nothing here clears a flight.';
    v_note_new text := 'No obstacle data exists. no_fly_zones lists the zones active when this plan was made; only the drop-off was checked against them when the order was placed, not the flight path. Nothing here clears a flight.';
    v_hits integer;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_order_flight_plan';

    IF v_def IS NULL THEN
        RAISE EXCEPTION 'get_order_flight_plan not found. Apply migrations 38 and 40 first.';
    END IF;

    IF position('active_no_fly_zones' IN v_def) > 0 THEN
        RAISE NOTICE 'The flight plan already carries the zones; nothing to do.';
        RETURN;
    END IF;

    v_hits := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);

    IF v_hits = 0 THEN
        RAISE EXCEPTION
            'Could not find the is_custom_dropoff key in get_order_flight_plan. '
            'It has drifted from migration 40; patch by hand.';
    END IF;
    IF v_hits > 1 THEN
        RAISE EXCEPTION 'That key appears % times; patch by hand.', v_hits;
    END IF;

    v_def := replace(v_def, v_old, v_new);

    -- Wording only, so a miss is reported rather than fatal
    IF position(v_note_old IN v_def) > 0 THEN
        v_def := replace(v_def, v_note_old, v_note_new);
    ELSE
        RAISE NOTICE 'The "no_fly_zones is empty" note was not found; _notes left as it is.';
    END IF;

    EXECUTE v_def;
    RAISE NOTICE 'get_order_flight_plan now carries the delivery zone and the no-fly zones.';
END;
$migration$;

REVOKE ALL ON FUNCTION public.get_order_flight_plan(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_order_flight_plan(uuid) TO authenticated;
