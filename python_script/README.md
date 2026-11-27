# AeroDrop ground-station bridge (`aio.py`)

Runs on the laptop next to Mission Planner. The admin taps **Send to drone** in
the AeroDrop app; the bridge checks the order, arms the drone, flies it to the
drop-off, releases the package, flies home, and streams the drone's real
telemetry to Supabase the whole time, so the app and the website track it live.

```
AeroDrop app ──UDP 5005──▶ aio.py ──MAVLink (Mission Planner mirror)──▶ RadioMaster Nomad ──ELRS──▶ ArduPilot H743
                             │
                             └──HTTPS──▶ Supabase (telemetry, delivery status)
```

## One-time setup

1. **Python packages:** `py -m pip install -r requirements.txt`
2. **Settings:** copy `bridge.env.example` to `bridge.env` and fill in:
   - the Supabase URL and anon key;
   - an AeroDrop **administrator** email and password.
   `bridge.env` is ignored by git. Never commit it.
3. **Database:** apply `supabase/migrations/46_real_drone_telemetry.sql`, which adds `record_drone_telemetry`.
4. **Mission Planner:**
   1. Connect to the drone.
   2. Press Ctrl+F, then **MAVLink**.
   3. Set **UDP Inbound/Outbound** to port **14551** and tick **Write Access**.
5. **ArduPilot:**
   - Set `SERVO9_FUNCTION = 0`. The servo is on pad S1, output 9.
   - Set RTL to land at home. This is ArduPilot's default.
6. **Check:** run `py aio.py --check`. It only signs in to Supabase and should print `Signed in as ...`.

## Each delivery

1. Mission Planner is connected and the drone is at the base hub with the package attached.
2. Run `py aio.py`. Wait for `Connected to Autopilot` and the `[STATUS]` lines.
3. In the AeroDrop app, open **Admin > Deliveries**, choose the delivery (status *assigning*), and tap **Send to drone**.
   - The first time, set the ground station address to the laptop's Wi-Fi IP, for example `192.168.1.100`.
   - The phone and the laptop must be on the same Wi-Fi.
   - A browser can't send UDP, so this only works from the app.
4. The app shows the bridge's answer. It's either `Started: ...` or the reason the bridge refused.

## What the bridge checks before the drone moves

| Check | Refuses when |
|---|---|
| Delivery | It isn't in *assigning* with a drone assigned |
| Coordinates | The app's target is more than `COORD_MATCH_M` (5 m) from the order's drop-off |
| Delivery zone | The drop-off is outside the zone |
| No-fly zones | The drop-off is inside a zone, or the straight route passes within `NO_FLY_MARGIN_M` (10 m) of one |
| Weather | Flights are grounded |
| Drone | No heartbeat, no 3D GPS fix, battery below `MIN_BATTERY_PCT` (40%), already armed, or more than `BASE_RADIUS_M` (30 m) from the base hub |
| Busy | Another delivery is still flying |

## The flight

1. **Take off.** GUIDED → arm → take off to the cruise altitude from the flight plan. The delivery becomes **in transit**.
2. **Fly to the drop-off.** The drone flies there in a straight line. Progress is sent with each telemetry point.
3. **Descend.** The drone drops to half the cruise altitude.
4. **Release.** Servo LOW, then a wait of `DROP_DELAY_SEC`. The delivery becomes **delivered**.
5. **Return.** RTL: ArduPilot flies home and lands. When the drone disarms, it is **available** again.

Telemetry is sent every second: position, altitude, ground speed (m/s), battery, ELRS link quality (RSSI) and heading.

## Safety

- **Pilot takeover.** If the pilot switches mode on the RadioMaster, or ArduPilot triggers a failsafe, the script stops sending commands immediately. It keeps reporting telemetry until the drone disarms. Resolve the delivery in the admin app afterwards.
- **Timeout or error mid-air.** The script asks for RTL.
- **Ctrl+C.** Stops the bridge. The drone keeps whatever mode it's in.

## Tests

`py -m unittest test_aio -v`

No drone or Supabase is needed. The tests cover:
- the geometry and the safety checks;
- a full simulated delivery;
- a pilot takeover.
