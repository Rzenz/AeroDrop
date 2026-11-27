"""Tests for the ground-station bridge. Run: py -m unittest test_aio -v

No drone or Supabase needed: the last test flies a whole delivery against a
fake flight controller (simple physics) and a fake Supabase, and checks the
commands and status calls happen in the right order."""
import json
import threading
import time
import unittest

import aio

HUB = (10.32613, 123.95462)
DROP = (10.32700, 123.95520)      # about 115 m north-east of the hub


def plan(drop=DROP, zones=None, radius=600.0, alt=20):
    return {
        "altitude_m_agl": alt,
        "delivery_zone": {"center_latitude": HUB[0], "center_longitude": HUB[1], "radius_meters": radius},
        "no_fly_zones": zones or [],
        "waypoints": [
            {"seq": 1, "role": "launch", "latitude": HUB[0], "longitude": HUB[1], "altitude_m_agl": 0},
            {"seq": 2, "role": "pickup", "latitude": HUB[0], "longitude": HUB[1], "altitude_m_agl": alt},
            {"seq": 3, "role": "dropoff", "latitude": drop[0], "longitude": drop[1], "altitude_m_agl": alt},
            {"seq": 4, "role": "return", "latitude": HUB[0], "longitude": HUB[1], "altitude_m_agl": 0},
        ],
    }


def cmd(lat=DROP[0], lon=DROP[1], alt=20.0):
    return aio.Command("d-1", lat, lon, alt)


class Geometry(unittest.TestCase):
    def test_haversine_known_distance(self):
        # 0.001 degree of latitude is about 111 m
        self.assertAlmostEqual(aio.haversine_meters(10.0, 124.0, 10.001, 124.0), 111.2, delta=0.5)

    def test_segment_distance_to_middle_and_ends(self):
        a, b = (10.0, 124.0), (10.0, 124.002)
        mid_above = (10.0005, 124.001)          # ~55 m north of the middle of the segment
        self.assertAlmostEqual(aio.segment_distance_m(*mid_above, *a, *b), 55.6, delta=1.0)
        beyond = (10.0, 124.003)                # past B: distance to B itself
        self.assertAlmostEqual(aio.segment_distance_m(*beyond, *a, *b), aio.haversine_meters(*beyond, *b), delta=1.0)

    def test_route_conflicts(self):
        zone_on_route = {"name": "Library", "latitude": 10.32656, "longitude": 123.95491, "radius_meters": 20}
        zone_away = {"name": "Gym", "latitude": 10.3300, "longitude": 123.9500, "radius_meters": 20}
        self.assertEqual(aio.route_conflicts(HUB, DROP, [zone_on_route, zone_away]), ["Library"])
        self.assertEqual(aio.route_conflicts(HUB, DROP, [{"name": "bad"}]), [])  # half-filled row ignored

    def test_progress(self):
        self.assertEqual(aio.flight_progress(100, 100), 0.0)
        self.assertEqual(aio.flight_progress(100, 25), 0.75)
        self.assertEqual(aio.flight_progress(100, 150), 0.0)
        self.assertEqual(aio.flight_progress(0, 0), 1.0)


class ParseCommand(unittest.TestCase):
    def test_json_with_lng(self):
        c = aio.parse_command('{"delivery_id": "abc", "lat": 10.1, "lng": 123.9, "alt": 20}')
        self.assertEqual((c.delivery_id, c.lat, c.lon, c.alt), ("abc", 10.1, 123.9, 20.0))

    def test_alt_optional(self):
        self.assertIsNone(aio.parse_command('{"delivery_id": "abc", "lat": 1, "lon": 2}').alt)

    def test_refuses_csv_and_missing_id(self):
        for raw in ("10.1,123.9,20", '{"lat": 1, "lon": 2, "alt": 3}', "", '{"delivery_id": "x", "lat": 1}'):
            with self.assertRaises(ValueError, msg=raw):
                aio.parse_command(raw)


class CheckPlan(unittest.TestCase):
    def test_good_plan(self):
        alt, drop, problems = aio.check_plan(cmd(), plan(), HUB, {"safety_status": "safe", "dispatch_enabled": True})
        self.assertEqual((alt, drop, problems), (20.0, DROP, []))

    def test_uses_plan_altitude_when_app_sends_none(self):
        alt, _, problems = aio.check_plan(cmd(alt=None), plan(alt=25), HUB, None)
        self.assertEqual((alt, problems), (25.0, []))

    def test_wrong_coordinates(self):
        _, _, problems = aio.check_plan(cmd(lat=DROP[0] + 0.001), plan(), HUB, None)
        self.assertTrue(any("from the order's drop-off" in p for p in problems), problems)

    def test_altitude_out_of_range(self):
        _, _, problems = aio.check_plan(cmd(alt=500), plan(), HUB, None)
        self.assertTrue(any("out of range" in p for p in problems), problems)

    def test_outside_delivery_zone(self):
        _, _, problems = aio.check_plan(cmd(), plan(radius=50), HUB, None)
        self.assertIn("The drop-off is outside the delivery zone", problems)

    def test_dropoff_inside_no_fly_zone(self):
        z = {"name": "Chapel", "latitude": DROP[0], "longitude": DROP[1], "radius_meters": 30}
        _, _, problems = aio.check_plan(cmd(), plan(zones=[z]), HUB, None)
        self.assertIn('The drop-off is inside the no-fly zone "Chapel"', problems)

    def test_route_through_no_fly_zone(self):
        z = {"name": "Library", "latitude": 10.32656, "longitude": 123.95491, "radius_meters": 15}
        _, _, problems = aio.check_plan(cmd(), plan(zones=[z]), HUB, None)
        self.assertIn('The straight route passes through the no-fly zone "Library"', problems)

    def test_grounded_weather(self):
        _, _, problems = aio.check_plan(cmd(), plan(), HUB, {"safety_status": "grounded", "dispatch_enabled": False})
        self.assertIn("Flights are grounded by the weather", problems)

    def test_old_plan_without_zone(self):
        p = plan(); del p["delivery_zone"]
        _, _, problems = aio.check_plan(cmd(), p, HUB, None)
        self.assertTrue(any("no delivery zone" in x for x in problems), problems)


class Preflight(unittest.TestCase):
    def ready(self, **kw):
        s = aio.DroneState(lat=HUB[0], lon=HUB[1], rel_alt=0, battery_pct=95, gps_fix=3, satellites=12,
                           mode=0, armed=False, heartbeat_at=time.time())
        for k, v in kw.items():
            setattr(s, k, v)
        return aio.preflight(s)

    def test_ready(self):
        self.assertEqual(self.ready(), [])

    def test_each_problem(self):
        self.assertTrue(self.ready(battery_pct=20)[0].startswith("Battery is 20%"))
        self.assertTrue(self.ready(gps_fix=1)[0].startswith("GPS fix is 1"))
        self.assertIn("The drone is already armed", self.ready(armed=True))
        self.assertIn("No heartbeat from the flight controller", self.ready(heartbeat_at=0))


# ---------------------------------------------------------------- full flight
class FakeMav:
    """Stands in for pymavlink's master.mav and flies a point-mass drone."""

    def __init__(self, sim):
        self.sim = sim

    def set_mode_send(self, _sys, _flag, mode):
        self.sim.log.append(("mode", mode))
        self.sim.mode = mode

    def command_long_send(self, _sys, _comp, command, _conf, p1, p2, p3, p4, p5, p6, p7):
        from pymavlink import mavutil
        m = mavutil.mavlink
        if command == m.MAV_CMD_COMPONENT_ARM_DISARM:
            self.sim.log.append(("arm", int(p1)))
            self.sim.armed = bool(p1)
        elif command == m.MAV_CMD_NAV_TAKEOFF:
            self.sim.log.append(("takeoff", p7))
            self.sim.target = (self.sim.lat, self.sim.lon, p7)
        elif command == m.MAV_CMD_DO_SET_SERVO:
            self.sim.log.append(("servo", int(p1), int(p2)))

    def set_position_target_global_int_send(self, _t, _s, _c, _frame, _mask, lat, lon, alt, *_rest):
        self.sim.target = (lat / 1e7, lon / 1e7, alt)


class FakeSim:
    SPEED = 60.0   # m/s, so the test flies in a couple of seconds

    def __init__(self):
        self.lat, self.lon = HUB
        self.alt = 0.0
        self.mode, self.armed = 0, False
        self.target = None
        self.log = []
        self.target_system, self.target_component = 1, 1
        self.mav = FakeMav(self)
        self.stop = False

    def step(self, dt):
        if self.mode == aio.RTL and self.armed:
            self.target = (HUB[0], HUB[1], 0.0)
        if self.armed and self.target:
            tl, tn, ta = self.target
            d = aio.haversine_meters(self.lat, self.lon, tl, tn)
            move = min(d, self.SPEED * dt)
            if d > 0:
                self.lat += (tl - self.lat) * move / d
                self.lon += (tn - self.lon) * move / d
            self.alt += max(-self.SPEED * dt, min(self.SPEED * dt, ta - self.alt))
            if self.mode == aio.RTL and d < 0.5 and self.alt <= 0.05:
                self.armed = False          # ArduPilot disarms after landing
        with aio.drone.lock:
            aio.drone.lat, aio.drone.lon, aio.drone.rel_alt = self.lat, self.lon, self.alt
            aio.drone.mode, aio.drone.armed = self.mode, self.armed
            aio.drone.battery_pct, aio.drone.gps_fix, aio.drone.satellites = 90.0, 3, 14
            aio.drone.heartbeat_at = aio.drone.position_at = time.time()
            aio.drone.groundspeed = self.SPEED if self.armed else 0.0

    def run(self):
        while not self.stop:
            self.step(0.05)
            time.sleep(0.05)


class FakeSupabase:
    def __init__(self, status="assigning"):
        self.calls = []
        self.telemetry = []
        self.status = status

    def select(self, table, query):
        if table == "deliveries":
            return [{"id": "d-1", "order_id": "o-1", "status": self.status, "drone_id": "drn-uuid"}]
        if table == "weather_safety":
            return [{"safety_status": "safe", "dispatch_enabled": True}]
        return []

    def rpc(self, fn, params):
        if fn == "get_order_flight_plan":
            return plan()
        if fn == "record_drone_telemetry":
            self.telemetry.append(params)
        else:
            self.calls.append((fn, params))
        return None


class FullFlight(unittest.TestCase):
    def setUp(self):
        aio.active_mission = None
        aio.drone = aio.DroneState()
        self.saved = (aio.DROP_DELAY_SEC, aio.TELEMETRY_INTERVAL)
        aio.DROP_DELAY_SEC, aio.TELEMETRY_INTERVAL = 0.1, 0.1
        self.sim = FakeSim()
        self.sim.step(0)
        self.t = threading.Thread(target=self.sim.run, daemon=True)
        self.t.start()

    def tearDown(self):
        self.sim.stop = True
        aio.DROP_DELAY_SEC, aio.TELEMETRY_INTERVAL = self.saved

    def payload(self, **kw):
        d = {"delivery_id": "d-1", "lat": DROP[0], "lon": DROP[1], "alt": 20}
        d.update(kw)
        return json.dumps(d)

    def test_delivers_and_returns(self):
        sb = FakeSupabase()
        reply = aio.handle_command(self.sim, sb, self.payload())
        self.assertTrue(reply["ok"], reply)
        self.assertTrue(aio.active_mission.done.wait(30), "mission did not finish")
        self.assertEqual(aio.active_mission.outcome, "completed")

        # Commands to the drone, in order
        kinds = [e[0] for e in self.sim.log]
        self.assertEqual(kinds, ["mode", "arm", "takeoff", "servo", "mode"])
        self.assertEqual(self.sim.log[0], ("mode", aio.GUIDED))
        self.assertEqual(self.sim.log[3], ("servo", aio.SERVO_CHANNEL, aio.SERVO_LOW_PWM))
        self.assertEqual(self.sim.log[4], ("mode", aio.RTL))

        # Status changes in Supabase, in order
        self.assertEqual([c[0] for c in sb.calls],
                         ["confirm_package_pickup", "complete_delivery_order", "complete_drone_return"])
        self.assertEqual(sb.calls[2][1], {"p_drone_id": "drn-uuid"})

        # Telemetry: real positions, progress only on the way out, then the return leg
        self.assertGreater(len(sb.telemetry), 5)
        events = [t["p_event_type"] for t in sb.telemetry]
        self.assertIn("in_flight", events)
        self.assertEqual(events[-1], "returning_to_base")
        self.assertTrue(all(t["p_progress"] is None for t in sb.telemetry if t["p_event_type"] == "returning_to_base"))
        self.assertTrue(any((t["p_progress"] or 0) > 0.5 for t in sb.telemetry))

    def test_refuses_second_command_while_flying(self):
        sb = FakeSupabase()
        self.assertTrue(aio.handle_command(self.sim, sb, self.payload())["ok"])
        reply = aio.handle_command(self.sim, sb, self.payload())
        self.assertFalse(reply["ok"])
        self.assertIn("Busy", reply["message"])
        aio.active_mission.done.wait(30)

    def test_refuses_delivery_not_waiting(self):
        reply = aio.handle_command(self.sim, FakeSupabase(status="delivered"), self.payload())
        self.assertFalse(reply["ok"])
        self.assertIn("not waiting for a flight", reply["message"])
        self.assertEqual(self.sim.log, [])

    def test_refuses_wrong_coordinates_without_moving(self):
        reply = aio.handle_command(self.sim, FakeSupabase(), self.payload(lat=DROP[0] + 0.01))
        self.assertFalse(reply["ok"])
        self.assertEqual(self.sim.log, [])

    def test_pilot_override_stops_commands(self):
        sb = FakeSupabase()
        self.assertTrue(aio.handle_command(self.sim, sb, self.payload())["ok"])
        # Wait until airborne and en route, then the pilot flips to LOITER
        deadline = time.time() + 10
        while time.time() < deadline and not any(c[0] == "confirm_package_pickup" for c in sb.calls):
            time.sleep(0.05)
        self.sim.mode = 5
        n = len(self.sim.log)
        self.sim.armed = False   # pilot lands and disarms
        self.assertTrue(aio.active_mission.done.wait(10))
        self.assertTrue(aio.active_mission.outcome.startswith("pilot control"), aio.active_mission.outcome)
        self.assertEqual(self.sim.log[n:], [], "the script sent commands after the pilot took over")
        self.assertNotIn("complete_delivery_order", [c[0] for c in sb.calls])


if __name__ == "__main__":
    unittest.main()
