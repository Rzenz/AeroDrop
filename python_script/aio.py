"""AeroDrop ground-station bridge.

Runs on the operator's laptop next to Mission Planner. It:

1. listens for a "send to drone" command from the AeroDrop app (UDP 5005 or
   TCP 5006), a JSON payload: {"delivery_id": "...", "lat": .., "lon": .., "alt": ..}
2. checks the command against Supabase before anything moves: the delivery is
   waiting for its flight, the coordinates are the order's drop-off, the
   drop-off is inside the delivery zone, the straight route crosses no no-fly
   zone, and the weather is not grounded
3. checks the drone: GPS fix, battery, and that it is sitting at the base hub
4. arms, takes off, flies to the drop-off in GUIDED mode, descends to half the
   cruise altitude, sets the servo LOW to release the package, waits, and
   switches to RTL so ArduPilot flies home and lands
5. sends the drone's real position, altitude, speed, battery, signal and
   heading to Supabase every second, so the app and the website track it
6. moves the delivery through its states: in transit after takeoff, delivered
   after the drop, and the drone back to available after it lands

If the pilot flips the RadioMaster to another mode at any point (or ArduPilot
triggers a failsafe), the script stops commanding the drone at once and only
keeps reporting telemetry.

Setup: see README.md in this folder.
"""
from __future__ import annotations

import json
import math
import os
import socket
import sys
import threading
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field

HERE = os.path.dirname(os.path.abspath(__file__))


# ==========================================
# CONFIGURATION (override any of these in bridge.env)
# ==========================================
def load_env(path: str) -> dict:
    """KEY=VALUE lines; blank lines and # comments ignored."""
    env = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    return env


_ENV = load_env(os.path.join(HERE, "bridge.env"))


def cfg(name: str, default=None, cast=str):
    raw = os.environ.get(name, _ENV.get(name))
    if raw is None or raw == "":
        return default
    return cast(raw)


# Supabase (the operator signs in with an AeroDrop administrator account)
SUPABASE_URL = (cfg("SUPABASE_URL", "") or "").rstrip("/")
SUPABASE_ANON_KEY = cfg("SUPABASE_ANON_KEY", "")
OPERATOR_EMAIL = cfg("OPERATOR_EMAIL", "")
OPERATOR_PASSWORD = cfg("OPERATOR_PASSWORD", "")

# Mission Planner MAVLink Mirroring UDP Port (must have "Write Access" checked!)
MAVLINK_CONN_STR = cfg("MAVLINK_CONN_STR", "udpin:127.0.0.1:14551")

# Ports for the AeroDrop app to send the delivery command to
FLUTTER_BIND_IP = cfg("FLUTTER_BIND_IP", "0.0.0.0")
FLUTTER_UDP_PORT = cfg("FLUTTER_UDP_PORT", 5005, int)
FLUTTER_TCP_PORT = cfg("FLUTTER_TCP_PORT", 5006, int)

# Servo Configuration (Pad S1 on DakeFPV H743 = Output 9; set SERVO9_FUNCTION = 0)
SERVO_CHANNEL = cfg("SERVO_CHANNEL", 9, int)
SERVO_LOW_PWM = cfg("SERVO_LOW_PWM", 1000, int)
SERVO_HIGH_PWM = cfg("SERVO_HIGH_PWM", 2000, int)

# Arrival & Drop Sequence Settings
WAYPOINT_RADIUS_M = cfg("WAYPOINT_RADIUS_M", 2.5, float)  # horizontal distance to count as "arrived"
ALT_TOLERANCE_M = cfg("ALT_TOLERANCE_M", 1.0, float)      # vertical distance to count as "at drop altitude"
DROP_DELAY_SEC = cfg("DROP_DELAY_SEC", 3.0, float)        # wait after servo LOW before RTL
MIN_ALT_METERS = cfg("MIN_ALT_METERS", 2.0, float)        # safety floor
MAX_ALT_METERS = cfg("MAX_ALT_METERS", 120.0, float)      # safety ceiling

# Pre-flight checks
MIN_BATTERY_PCT = cfg("MIN_BATTERY_PCT", 40.0, float)     # refuse to take off below this
MIN_GPS_FIX = cfg("MIN_GPS_FIX", 3, int)                  # 3 = 3D fix
BASE_RADIUS_M = cfg("BASE_RADIUS_M", 30.0, float)         # drone must start this close to the base hub
COORD_MATCH_M = cfg("COORD_MATCH_M", 5.0, float)          # app's target vs. the order's drop-off
NO_FLY_MARGIN_M = cfg("NO_FLY_MARGIN_M", 10.0, float)     # extra clearance around each no-fly zone

# Timeouts (seconds)
MODE_TIMEOUT = cfg("MODE_TIMEOUT", 5.0, float)
ARM_TIMEOUT = cfg("ARM_TIMEOUT", 10.0, float)
TAKEOFF_TIMEOUT = cfg("TAKEOFF_TIMEOUT", 60.0, float)
FLIGHT_TIMEOUT = cfg("FLIGHT_TIMEOUT", 600.0, float)
LANDING_TIMEOUT = cfg("LANDING_TIMEOUT", 600.0, float)
TELEMETRY_INTERVAL = cfg("TELEMETRY_INTERVAL", 1.0, float)

# ArduCopter custom modes
GUIDED, RTL, LAND = 4, 6, 9
MODE_NAMES = {0: "STABILIZE", 2: "ALT_HOLD", 3: "AUTO", 4: "GUIDED", 5: "LOITER", 6: "RTL", 9: "LAND", 16: "POSHOLD"}


def log(msg: str):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


# ==========================================
# GEOMETRY (pure, unit-tested in test_aio.py)
# ==========================================
def haversine_meters(lat1, lon1, lat2, lon2):
    """Calculates horizontal distance in meters between two GPS coordinates."""
    r = 6371000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = (
        math.sin(dphi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2.0) ** 2
    )
    return 2.0 * r * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))


def segment_distance_m(p_lat, p_lon, a_lat, a_lon, b_lat, b_lon):
    """Shortest distance (m) from point P to the straight segment A-B.

    Uses a flat projection around A, which is accurate to well under a metre
    over a campus-sized flight."""
    k = 111320.0
    cos0 = math.cos(math.radians(a_lat))

    def xy(lat, lon):
        return ((lon - a_lon) * k * cos0, (lat - a_lat) * k)

    px, py = xy(p_lat, p_lon)
    bx, by = xy(b_lat, b_lon)
    seg2 = bx * bx + by * by
    t = 0.0 if seg2 == 0 else max(0.0, min(1.0, (px * bx + py * by) / seg2))
    dx, dy = px - t * bx, py - t * by
    return math.hypot(dx, dy)


def route_conflicts(start, end, zones, margin_m=0.0):
    """Names of the no-fly zones the straight route start->end passes through."""
    hits = []
    for z in zones or []:
        try:
            lat, lon, rad = float(z["latitude"]), float(z["longitude"]), float(z["radius_meters"])
        except (KeyError, TypeError, ValueError):
            continue
        if rad <= 0:
            continue
        if segment_distance_m(lat, lon, start[0], start[1], end[0], end[1]) <= rad + margin_m:
            hits.append(str(z.get("name") or "unnamed zone"))
    return hits


def flight_progress(total_m, remaining_m):
    """0.0 at takeoff, 1.0 at the drop-off."""
    if total_m <= 0:
        return 1.0
    return max(0.0, min(1.0, 1.0 - remaining_m / total_m))


# ==========================================
# COMMAND PARSING (pure)
# ==========================================
@dataclass
class Command:
    delivery_id: str
    lat: float
    lon: float
    alt: float | None


def parse_command(raw: str) -> Command:
    """The app's payload: JSON with delivery_id, lat, lon (or lng/long) and an
    optional alt. A bare "lat,lon,alt" is refused: without the delivery id the
    flight cannot be checked against an order or tracked."""
    raw = (raw or "").strip()
    if not raw:
        raise ValueError("Empty payload")
    if not raw.startswith("{"):
        raise ValueError("Send JSON with delivery_id, lat, lon and alt")
    data = json.loads(raw)
    did = str(data.get("delivery_id") or "").strip()
    if not did:
        raise ValueError("delivery_id is required")
    lon = data.get("lon", data.get("lng", data.get("long")))
    if data.get("lat") is None or lon is None:
        raise ValueError("lat and lon are required")
    alt = data.get("alt")
    return Command(did, float(data["lat"]), float(lon), None if alt is None else float(alt))


def find_waypoint(plan: dict, role: str):
    for wp in plan.get("waypoints") or []:
        if wp.get("role") == role:
            return wp
    return None


def check_plan(cmd: Command, plan: dict, drone_pos, weather: dict | None):
    """Every check that needs only data, no drone. Returns (cruise_alt, dropoff, problems)."""
    problems = []
    drop = find_waypoint(plan, "dropoff")
    if not drop or drop.get("latitude") is None:
        return None, None, ["The order has no drop-off position"]
    drop_ll = (float(drop["latitude"]), float(drop["longitude"]))

    off = haversine_meters(cmd.lat, cmd.lon, *drop_ll)
    if off > COORD_MATCH_M:
        problems.append(f"The coordinates sent are {off:.0f} m from the order's drop-off")

    alt = cmd.alt if cmd.alt is not None else plan.get("altitude_m_agl")
    try:
        alt = float(alt)
    except (TypeError, ValueError):
        alt = None
    if alt is None or not (MIN_ALT_METERS <= alt <= MAX_ALT_METERS):
        problems.append(f"Altitude {alt} m is out of range ({MIN_ALT_METERS}-{MAX_ALT_METERS} m)")

    zone = plan.get("delivery_zone") or {}
    try:
        zc = (float(zone["center_latitude"]), float(zone["center_longitude"]))
        zr = float(zone["radius_meters"])
        if haversine_meters(*zc, *drop_ll) > zr:
            problems.append("The drop-off is outside the delivery zone")
    except (KeyError, TypeError, ValueError):
        problems.append("The flight plan has no delivery zone; download a fresh one after migration 45")

    zones = plan.get("no_fly_zones") or []
    inside = route_conflicts(drop_ll, drop_ll, zones)
    if inside:
        problems.append(f"The drop-off is inside the no-fly zone \"{inside[0]}\"")
    elif drone_pos:
        crossed = route_conflicts(drone_pos, drop_ll, zones, NO_FLY_MARGIN_M)
        if crossed:
            problems.append(f"The straight route passes through the no-fly zone \"{crossed[0]}\"")

    if weather is not None:
        if weather.get("safety_status") == "grounded" or weather.get("dispatch_enabled") is False:
            problems.append("Flights are grounded by the weather")

    return alt, drop_ll, problems


# ==========================================
# SUPABASE (plain HTTPS, no extra packages)
# ==========================================
class SupabaseError(Exception):
    pass


class Supabase:
    def __init__(self, url, anon_key, email, password):
        if not (url and anon_key and email and password):
            raise SupabaseError(
                "Set SUPABASE_URL, SUPABASE_ANON_KEY, OPERATOR_EMAIL and OPERATOR_PASSWORD in bridge.env"
            )
        self.url, self.key = url, anon_key
        self.email, self.password = email, password
        self.token = None
        self.refresh_token = None
        self.expires_at = 0.0
        self.lock = threading.Lock()

    def _http(self, method, path, body=None, auth=True):
        headers = {"apikey": self.key, "Content-Type": "application/json"}
        if auth:
            headers["Authorization"] = f"Bearer {self._access_token()}"
        data = None if body is None else json.dumps(body).encode("utf-8")
        req = urllib.request.Request(self.url + path, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=10) as res:
                txt = res.read().decode("utf-8")
                return json.loads(txt) if txt else None
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "ignore")
            try:
                j = json.loads(detail)
                detail = j.get("message") or j.get("msg") or j.get("error_description") or detail
            except ValueError:
                pass
            raise SupabaseError(detail) from None
        except urllib.error.URLError as e:
            raise SupabaseError(f"Cannot reach Supabase: {e.reason}") from None

    def sign_in(self):
        res = self._http(
            "POST", "/auth/v1/token?grant_type=password",
            {"email": self.email, "password": self.password}, auth=False,
        )
        self._store(res)
        return res.get("user", {}).get("email")

    def _store(self, res):
        self.token = res["access_token"]
        self.refresh_token = res.get("refresh_token")
        self.expires_at = time.time() + float(res.get("expires_in", 3600))

    def _access_token(self):
        with self.lock:
            if self.token and time.time() < self.expires_at - 60:
                return self.token
            if self.refresh_token:
                try:
                    res = self._http(
                        "POST", "/auth/v1/token?grant_type=refresh_token",
                        {"refresh_token": self.refresh_token}, auth=False,
                    )
                    self._store(res)
                    return self.token
                except SupabaseError:
                    pass
            self._store(self._http(
                "POST", "/auth/v1/token?grant_type=password",
                {"email": self.email, "password": self.password}, auth=False,
            ))
            return self.token

    def rpc(self, fn, params):
        return self._http("POST", f"/rest/v1/rpc/{fn}", params)

    def select(self, table, query):
        return self._http("GET", f"/rest/v1/{table}?{query}") or []


# ==========================================
# MAVLINK
# ==========================================
@dataclass
class DroneState:
    lat: float | None = None
    lon: float | None = None
    rel_alt: float | None = None
    heading: float = 0.0
    groundspeed: float = 0.0
    battery_pct: float | None = None
    rssi_pct: float | None = None
    gps_fix: int = 0
    satellites: int = 0
    mode: int | None = None
    armed: bool = False
    heartbeat_at: float = 0.0
    position_at: float = 0.0
    lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    def snapshot(self):
        with self.lock:
            return DroneState(**{k: getattr(self, k) for k in self.__dataclass_fields__ if k != "lock"})


drone = DroneState()
mav_lock = threading.Lock()


def connect_mavlink():
    from pymavlink import mavutil

    log(f"[MAVLink] Connecting to mirrored stream on {MAVLINK_CONN_STR}...")
    master = mavutil.mavlink_connection(MAVLINK_CONN_STR)

    while True:
        msg = master.recv_match(type="HEARTBEAT", blocking=True)
        if msg and msg.get_srcComponent() == mavutil.mavlink.MAV_COMP_ID_AUTOPILOT1:
            master.target_system = msg.get_srcSystem()
            master.target_component = msg.get_srcComponent()
            log(f"[MAVLink] Connected to Autopilot! (SysID: {master.target_system}, CompID: {master.target_component})")
            break

    # Position, status and RC streams at 4 Hz so arrival checks are accurate
    master.mav.request_data_stream_send(
        master.target_system, master.target_component, mavutil.mavlink.MAV_DATA_STREAM_ALL, 4, 1,
    )
    return master


def mavlink_reader(master):
    """The only thread that reads the link; everything else reads `drone`."""
    from pymavlink import mavutil

    armed_flag = mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED
    while True:
        try:
            msg = master.recv_match(blocking=True, timeout=1.0)
        except Exception as e:  # a corrupt packet must not stop telemetry
            log(f"[MAVLink] read error: {e}")
            continue
        if msg is None:
            continue
        t = msg.get_type()
        now = time.time()
        with drone.lock:
            if t == "HEARTBEAT":
                if msg.get_srcSystem() == master.target_system and msg.get_srcComponent() == master.target_component:
                    drone.mode = msg.custom_mode
                    drone.armed = bool(msg.base_mode & armed_flag)
                    drone.heartbeat_at = now
            elif t == "GLOBAL_POSITION_INT":
                drone.lat = msg.lat / 1e7
                drone.lon = msg.lon / 1e7
                drone.rel_alt = msg.relative_alt / 1000.0
                if msg.hdg != 65535:
                    drone.heading = msg.hdg / 100.0
                drone.groundspeed = math.hypot(msg.vx, msg.vy) / 100.0
                drone.position_at = now
            elif t == "VFR_HUD":
                drone.groundspeed = float(msg.groundspeed)
            elif t == "SYS_STATUS":
                if msg.battery_remaining >= 0:
                    drone.battery_pct = float(msg.battery_remaining)
            elif t == "GPS_RAW_INT":
                drone.gps_fix = int(msg.fix_type)
                drone.satellites = int(msg.satellites_visible)
            elif t == "RC_CHANNELS":
                if msg.rssi != 255:
                    drone.rssi_pct = round(msg.rssi / 254.0 * 100.0, 1)


def set_flight_mode(master, mode_id: int):
    from pymavlink import mavutil

    with mav_lock:
        master.mav.set_mode_send(master.target_system, mavutil.mavlink.MAV_MODE_FLAG_CUSTOM_MODE_ENABLED, mode_id)
    log(f"[MODE] Requested {MODE_NAMES.get(mode_id, mode_id)}")


def command_long(master, command, *params):
    p = list(params) + [0.0] * (7 - len(params))
    with mav_lock:
        master.mav.command_long_send(master.target_system, master.target_component, command, 0, *[float(x) for x in p])


def arm(master):
    from pymavlink import mavutil

    command_long(master, mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM, 1)
    log("[ARM] Arming")


def takeoff(master, alt):
    from pymavlink import mavutil

    command_long(master, mavutil.mavlink.MAV_CMD_NAV_TAKEOFF, 0, 0, 0, 0, 0, 0, alt)
    log(f"[TAKEOFF] Climbing to {alt:.1f} m")


def send_guided_position(master, lat: float, lon: float, alt: float):
    """Sends a global GUIDED position target (alt in meters relative to Home)."""
    from pymavlink import mavutil

    type_mask = 0b0000111111111000  # Use Position X, Y, Z only
    with mav_lock:
        master.mav.set_position_target_global_int_send(
            0, master.target_system, master.target_component,
            mavutil.mavlink.MAV_FRAME_GLOBAL_RELATIVE_ALT_INT, type_mask,
            int(lat * 1e7), int(lon * 1e7), float(alt),
            0, 0, 0, 0, 0, 0, 0, 0,
        )


def set_servo_pwm(master, channel: int, pwm: int):
    """Sends MAV_CMD_DO_SET_SERVO (183) to set servo PWM."""
    from pymavlink import mavutil

    command_long(master, mavutil.mavlink.MAV_CMD_DO_SET_SERVO, channel, pwm)
    log(f"[SERVO] Set Servo {channel} -> {pwm} PWM")


# ==========================================
# MISSION
# ==========================================
class PilotOverride(Exception):
    """The mode left GUIDED without the script asking: the pilot or a failsafe has the drone."""


class Mission:
    """One delivery flight. Only one runs at a time."""

    def __init__(self, master, sb: Supabase, delivery: dict, cmd: Command, alt: float, drop_ll):
        self.master, self.sb = master, sb
        self.delivery_id = delivery["id"]
        self.drone_id = delivery["drone_id"]
        self.cmd, self.cruise_alt, self.target = cmd, alt, drop_ll
        self.drop_alt = max(1.0, alt / 2.0)
        self.event = "standby"
        self.progress = 0.0
        self.send_progress = True
        self.total_m = 0.0
        self.done = threading.Event()
        self.outcome = "running"

    # -- helpers
    def wait_for(self, cond, timeout, what, expect_mode=None):
        end = time.time() + timeout
        while time.time() < end:
            s = drone.snapshot()
            if expect_mode is not None and s.mode is not None and s.mode != expect_mode:
                raise PilotOverride(f"mode changed to {MODE_NAMES.get(s.mode, s.mode)} while {what}")
            if cond(s):
                return s
            time.sleep(0.2)
        raise TimeoutError(f"Timed out while {what}")

    def status_rpc(self, fn, params, what):
        try:
            self.sb.rpc(fn, params)
            log(f"[SUPABASE] {what}")
        except SupabaseError as e:
            log(f"[SUPABASE] {what} FAILED: {e}")

    # -- the flight
    def run(self):
        m = self.master
        try:
            log("=== STARTING DELIVERY SEQUENCE ===")
            log(f"Delivery {self.delivery_id[:8]} -> ({self.target[0]:.6f}, {self.target[1]:.6f}) | "
                f"Cruise Alt: {self.cruise_alt} m | Drop Alt: {self.drop_alt} m")

            # Step 1: GUIDED, arm, take off
            set_flight_mode(m, GUIDED)
            self.wait_for(lambda s: s.mode == GUIDED, MODE_TIMEOUT, "switching to GUIDED")
            arm(m)
            self.wait_for(lambda s: s.armed, ARM_TIMEOUT, "arming", expect_mode=GUIDED)
            takeoff(m, self.cruise_alt)
            self.event = "in_flight"
            self.wait_for(lambda s: (s.rel_alt or 0) >= self.cruise_alt * 0.9, TAKEOFF_TIMEOUT,
                          "taking off", expect_mode=GUIDED)
            log("[TAKEOFF] Cruise altitude reached")
            self.status_rpc("confirm_package_pickup", {"p_delivery_id": self.delivery_id},
                            "Delivery is now in transit")

            # Step 2: fly to the drop-off at cruise altitude
            s = drone.snapshot()
            self.total_m = haversine_meters(s.lat, s.lon, *self.target)
            last_resend = 0.0
            end = time.time() + FLIGHT_TIMEOUT
            while True:
                s = drone.snapshot()
                if s.mode != GUIDED:
                    raise PilotOverride(f"mode changed to {MODE_NAMES.get(s.mode, s.mode)} en route")
                if time.time() > end:
                    raise TimeoutError("Timed out flying to the drop-off")
                if time.time() - last_resend > 1.0:
                    send_guided_position(m, *self.target, self.cruise_alt)
                    last_resend = time.time()
                dist = haversine_meters(s.lat, s.lon, *self.target)
                self.progress = flight_progress(self.total_m, dist)
                if dist <= WAYPOINT_RADIUS_M:
                    log(f"[ARRIVED] Reached destination ({dist:.1f} m away)")
                    break
                time.sleep(0.25)

            # Step 3: drop to half altitude while holding the drop-off
            log(f"[DESCENDING] Dropping to {self.drop_alt:.1f} m")
            last_resend = 0.0
            end = time.time() + TAKEOFF_TIMEOUT
            while True:
                s = drone.snapshot()
                if s.mode != GUIDED:
                    raise PilotOverride(f"mode changed to {MODE_NAMES.get(s.mode, s.mode)} while descending")
                if time.time() > end:
                    raise TimeoutError("Timed out descending")
                if time.time() - last_resend > 1.0:
                    send_guided_position(m, *self.target, self.drop_alt)
                    last_resend = time.time()
                if s.rel_alt is not None and abs(s.rel_alt - self.drop_alt) <= ALT_TOLERANCE_M:
                    log(f"[ALTITUDE REACHED] Hovering at {s.rel_alt:.1f} m")
                    break
                time.sleep(0.25)

            # Step 4: release the package, then wait
            set_servo_pwm(m, SERVO_CHANNEL, SERVO_LOW_PWM)
            log(f"[DELAY] Waiting {DROP_DELAY_SEC}s for payload release...")
            time.sleep(DROP_DELAY_SEC)
            self.progress = 1.0
            self.status_rpc("complete_delivery_order", {"p_delivery_id": self.delivery_id},
                            "Delivery marked delivered")

            # Step 5: Return to Launch (Home) and land
            self.send_progress = False
            self.event = "returning_to_base"
            set_flight_mode(m, RTL)
            self.wait_for(lambda s: s.mode == RTL, MODE_TIMEOUT, "switching to RTL")
            log("[RTL] Returning home to land")
            self.wait_for(lambda s: not s.armed, LANDING_TIMEOUT, "returning and landing")
            log("[LANDED] Disarmed at base")
            self.status_rpc("complete_drone_return", {"p_drone_id": self.drone_id},
                            "Drone is available again")
            self.outcome = "completed"
            log("=== SEQUENCE COMPLETE ===")
        except PilotOverride as e:
            self.outcome = f"pilot control: {e}"
            log(f"[OVERRIDE] {e}. The script has stopped commanding the drone; the pilot has it.")
            log("[OVERRIDE] Telemetry continues until the drone disarms. Resolve the delivery in the admin app.")
            self.wait_disarmed_quietly()
        except Exception as e:
            self.outcome = f"aborted: {e}"
            log(f"[ABORTED] {e}")
            s = drone.snapshot()
            if s.armed and (s.rel_alt or 0) > 0.5 and s.mode == GUIDED:
                set_flight_mode(m, RTL)
                log("[ABORTED] Drone was airborne in GUIDED: requested RTL")
            self.wait_disarmed_quietly()
        finally:
            self.done.set()

    def wait_disarmed_quietly(self):
        self.send_progress = False
        end = time.time() + LANDING_TIMEOUT
        while time.time() < end and drone.snapshot().armed:
            time.sleep(0.5)

    # -- telemetry, on its own thread for the whole mission
    def telemetry_loop(self):
        failures = 0
        while not self.done.is_set():
            s = drone.snapshot()
            if s.lat is not None and s.lon is not None:
                try:
                    self.sb.rpc("record_drone_telemetry", {
                        "p_delivery_id": self.delivery_id,
                        "p_latitude": s.lat,
                        "p_longitude": s.lon,
                        "p_altitude": round(s.rel_alt or 0.0, 2),
                        "p_speed": round(s.groundspeed, 2),
                        "p_battery_level": s.battery_pct,
                        "p_signal_strength": s.rssi_pct,
                        "p_heading": round(s.heading, 1),
                        "p_event_type": self.event,
                        "p_progress": round(self.progress, 4) if self.send_progress else None,
                    })
                    failures = 0
                except SupabaseError as e:
                    failures += 1
                    if failures in (1, 10) or failures % 60 == 0:
                        log(f"[TELEMETRY] write failed ({failures}x): {e}")
            time.sleep(TELEMETRY_INTERVAL)


# ==========================================
# COMMAND HANDLING
# ==========================================
active_mission: Mission | None = None
mission_lock = threading.Lock()


def preflight(s: DroneState):
    problems = []
    if time.time() - s.heartbeat_at > 3:
        problems.append("No heartbeat from the flight controller")
    if s.gps_fix < MIN_GPS_FIX:
        problems.append(f"GPS fix is {s.gps_fix} with {s.satellites} satellites (need 3D fix)")
    if s.lat is None:
        problems.append("No position from the drone yet")
    if s.battery_pct is None:
        problems.append("No battery reading from the drone")
    elif s.battery_pct < MIN_BATTERY_PCT:
        problems.append(f"Battery is {s.battery_pct:.0f}% (need at least {MIN_BATTERY_PCT:.0f}%)")
    if s.armed:
        problems.append("The drone is already armed")
    return problems


def handle_command(master, sb: Supabase, raw: str) -> dict:
    global active_mission
    try:
        cmd = parse_command(raw)
    except (ValueError, json.JSONDecodeError) as e:
        return {"ok": False, "message": f"Bad command: {e}"}

    with mission_lock:
        if active_mission and not active_mission.done.is_set():
            return {"ok": False, "message": f"Busy: delivery {active_mission.delivery_id[:8]} is still flying"}

        try:
            rows = sb.select("deliveries", f"id=eq.{cmd.delivery_id}&select=id,order_id,status,drone_id")
        except SupabaseError as e:
            return {"ok": False, "message": f"Supabase: {e}"}
        if not rows:
            return {"ok": False, "message": "No such delivery"}
        delivery = rows[0]
        if delivery.get("status") != "assigning" or not delivery.get("drone_id"):
            return {"ok": False, "message": f"The delivery is not waiting for a flight (status: {delivery.get('status')})"}

        try:
            plan = sb.rpc("get_order_flight_plan", {"p_order_id": delivery["order_id"]})
            weather = (sb.select("weather_safety", "select=safety_status,dispatch_enabled&order=updated_at.desc&limit=1") or [None])[0]
        except SupabaseError as e:
            return {"ok": False, "message": f"Supabase: {e}"}

        s = drone.snapshot()
        problems = preflight(s)
        pos = (s.lat, s.lon) if s.lat is not None else None
        alt, drop_ll, plan_problems = check_plan(cmd, plan, pos, weather)
        problems += plan_problems

        base = find_waypoint(plan, "launch")
        if pos and base and base.get("latitude") is not None:
            d = haversine_meters(*pos, float(base["latitude"]), float(base["longitude"]))
            if d > BASE_RADIUS_M:
                problems.append(f"The drone is {d:.0f} m from the base hub (must be within {BASE_RADIUS_M:.0f} m)")

        if problems:
            log("[REFUSED] " + "; ".join(problems))
            return {"ok": False, "message": "; ".join(problems)}

        mission = Mission(master, sb, delivery, cmd, alt, drop_ll)
        active_mission = mission
        threading.Thread(target=mission.telemetry_loop, daemon=True).start()
        threading.Thread(target=mission.run, daemon=True).start()
        return {"ok": True, "message": f"Started: cruise {alt:g} m, drop at {mission.drop_alt:g} m"}


def udp_listener(master, sb):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((FLUTTER_BIND_IP, FLUTTER_UDP_PORT))
    log(f"[UDP Listener] Ready on {FLUTTER_BIND_IP}:{FLUTTER_UDP_PORT}")
    while True:
        data, addr = sock.recvfrom(4096)
        msg = data.decode("utf-8", errors="ignore")
        log(f"[UDP <- {addr[0]}:{addr[1]}] {msg.strip()}")
        reply = handle_command(master, sb, msg)
        sock.sendto(json.dumps(reply).encode("utf-8"), addr)


def tcp_listener(master, sb):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((FLUTTER_BIND_IP, FLUTTER_TCP_PORT))
    server.listen(5)
    log(f"[TCP Listener] Ready on {FLUTTER_BIND_IP}:{FLUTTER_TCP_PORT}")
    while True:
        conn, addr = server.accept()
        with conn:
            conn.settimeout(5)
            try:
                data = conn.recv(4096)
            except OSError:
                continue
            if data:
                msg = data.decode("utf-8", errors="ignore")
                log(f"[TCP <- {addr[0]}:{addr[1]}] {msg.strip()}")
                reply = handle_command(master, sb, msg)
                conn.sendall((json.dumps(reply) + "\n").encode("utf-8"))


def main(argv):
    sb = Supabase(SUPABASE_URL, SUPABASE_ANON_KEY, OPERATOR_EMAIL, OPERATOR_PASSWORD)
    who = sb.sign_in()
    log(f"[SUPABASE] Signed in as {who}")
    if "--check" in argv:
        log("[CHECK] Supabase sign-in works. Not connecting to the drone (--check).")
        return

    master = connect_mavlink()
    threading.Thread(target=mavlink_reader, args=(master,), daemon=True).start()
    threading.Thread(target=udp_listener, args=(master, sb), daemon=True).start()
    threading.Thread(target=tcp_listener, args=(master, sb), daemon=True).start()

    # Keep the process alive; the work happens on the threads above.
    last = 0.0
    try:
        while True:
            time.sleep(1)
            if time.time() - last >= 15:
                s = drone.snapshot()
                bat = "--" if s.battery_pct is None else f"{s.battery_pct:.0f}%"
                log(f"[STATUS] mode={MODE_NAMES.get(s.mode, s.mode)} armed={s.armed} gps_fix={s.gps_fix} "
                    f"sats={s.satellites} battery={bat} alt={s.rel_alt}")
                last = time.time()
    except KeyboardInterrupt:
        log("Stopping the bridge. The drone keeps whatever mode it is in.")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except SupabaseError as e:
        log(f"[SUPABASE] {e}")
        sys.exit(1)
