-- ============================================================================
-- 25_fix_stall_alert_repeat.sql
--
-- Migration 24's stalled-order alert suppressed itself only while an UNREAD
-- alert existed for that delivery. As soon as an admin opened it, the next
-- sweep -- one minute later -- raised another, and kept doing so every minute
-- for as long as the order stayed stuck. Reading the alert was what caused
-- the flood.
--
-- That pattern came from the chat notifications (migration 20), where
-- re-alerting after a read is correct: a new message is a new event. A stalled
-- delivery is not a new event each minute, it is one condition that persists.
--
-- Suppression is now time-based: at most one alert per delivery per hour,
-- whether or not anyone has read it. If an order stalls, is fixed, and stalls
-- again later, the admins are told again.
--
-- Only the suppression check changes; the rest of the function is its
-- migration 24 definition.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.resume_stalled_multi_trip_orders()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_row     RECORD;
    v_resumed integer := 0;
BEGIN
    FOR v_row IN
        SELECT d.id AS delivery_id,
               d.order_id,
               d.drone_id,
               d.updated_at,
               coalesce(d.trips_completed, 0) AS trips_done,
               coalesce(d.trips_required, 1)  AS trips_total
        FROM public.deliveries d
        JOIN public.drones dr ON dr.id = d.drone_id
        WHERE d.status = 'in_transit'
          AND coalesce(d.trips_completed, 0) < coalesce(d.trips_required, 1)
          AND dr.status = 'available'
          AND d.updated_at < now() - interval '1 minute'
    LOOP
        IF public.dispatch_next_queued_delivery(v_row.drone_id) THEN
            v_resumed := v_resumed + 1;
        ELSE
            -- Still blocked (grounded weather, or a flat battery). Tell the
            -- admins once per stalled delivery rather than every minute.
            IF v_row.updated_at < now() - interval '15 minutes'
               AND NOT EXISTS (
                   SELECT 1
                   FROM public.notifications n
                   JOIN public.users u ON u.id = n.user_id AND u.role = 'admin'
                   WHERE n.notification_type = 'multi_trip_stalled'
                     AND n.created_at > now() - interval '1 hour'
                     AND n.metadata->>'delivery_id' = v_row.delivery_id::text
               )
            THEN
                PERFORM public.notify_all_admins(
                    'Multi-trip order stalled',
                    'Order #' || substring(v_row.order_id::text, 1, 8) ||
                    ' has completed ' || v_row.trips_done || ' of ' ||
                    v_row.trips_total || ' drone trips and cannot continue. ' ||
                    'Check the weather status and the drone battery.',
                    'multi_trip_stalled',
                    v_row.delivery_id,
                    jsonb_build_object(
                        'delivery_id',     v_row.delivery_id,
                        'order_id',        v_row.order_id,
                        'trips_completed', v_row.trips_done,
                        'trips_required',  v_row.trips_total
                    )
                );
            END IF;
        END IF;
    END LOOP;

    RETURN v_resumed;
END;
$$;

REVOKE ALL ON FUNCTION public.resume_stalled_multi_trip_orders() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.resume_stalled_multi_trip_orders() TO postgres, service_role;
