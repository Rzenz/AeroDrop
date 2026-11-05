# AeroDrop website

The web front end for AeroDrop: a landing page for the app, plus customer, vendor and admin portals that use the same Supabase backend as the Flutter app. It is a separate React project; it does not embed or link to the Flutter build in `../web`.

## Run it

```bash
cd website
npm install
cp .env.example .env   # required: the app's Supabase URL and anon key
npm run dev            # http://localhost:5173
```

`npm run build` writes a static site to `dist/`. Any static host works; route every path to `index.html` so deep links like `/admin/drones` load.

## Connecting to the app's back end

The site has no data of its own. It needs the same Supabase project the Flutter app is built with:

| Variable | Value |
|---|---|
| `VITE_SUPABASE_URL` | The app's `--dart-define=SUPABASE_URL` |
| `VITE_SUPABASE_ANON_KEY` | The app's `--dart-define=SUPABASE_ANON_KEY` (the public anon key, never the service role key) |
| `VITE_PLAY_STORE_URL` | The app's Google Play listing. Download buttons stay hidden until it is set. |

`npm run build` stops with an error if either Supabase value is missing, so a build can never ship without the app's database.

The site calls the same tables, RPCs and edge functions as the app (`place_order`, `customer_cancel_order`, `vendor_mark_order_ready`, `submit_order_reviews`, `get_vendor_reviews`, `get_product_reviews`, `set_simulated_weather`, `create-xendit-payment`, and so on). Row level security therefore applies to the website exactly as it does to the app. Accounts, sign-in codes, orders and payments are shared: an account made on one works on the other.

## How the website stays in sync with the app

The website uses the app's back end directly. It has no server and no API of its own.

- **Flights.** `src/lib/flight-sim.ts` is a line-by-line port of `DeliveryNotifier._startSimulation`, and `src/lib/flight-calc.ts` ports `DroneFlightCalculator`. Every signed-in portal runs the simulator every 3 seconds, the same as an open phone, so a delivery keeps flying whether its watcher is on the app or the website:
  - Leg 1 (hub to vendor) runs while the delivery is `assigning`, then `confirm_package_pickup` is called.
  - Leg 2 (vendor to drop-off) runs while it is `in_transit`, then `complete_delivery_order` is called.
  - Leg 3 (the return) runs only for the client that wins `claim_drone_sim_lease`. It ends in `arrive_at_vendor_for_next_trip` for multi-trip orders, otherwise in `complete_drone_return`.
  - `recover_stale_returning_drone` runs every 15 seconds.
  - Writes go through `record_simulated_telemetry`. The single-writer guard and the lease are the app's own, so two open clients never move a drone twice.
- **Realtime.** `subscribeChanges` opens one channel on `orders`, `deliveries`, `drones`, `weather_safety`, `order_messages`, `products`, `support_reports`, `users` and the viewer's `notifications`. Admins also get `drone_telemetry` and `delivery_status_logs`.
- **Account status.** As in `UserShell`, customers and vendors are checked every 10 seconds. A suspended or deleted account gets the blocking "Account Suspended" dialog.
- **Auth.**
  - Email and password with the emailed code.
  - Resend code with a 60-second cooldown.
  - Google OAuth. It returns to `/auth/callback` and refuses admin, suspended and deleted accounts.
  - The Google-only account check on sign-in and password reset.
  - `/complete-profile` for accounts without a phone number, using the app's PH number rules.
  - The 6-character password minimum.
- **Storage.** The app's buckets and paths: `avatars/<uid>/avatar.<ext>`, `vendor-logos/<uid>/logo.<ext>` (or `business_logo.<ext>` at sign-up), and `product-images/<uid>/prod_<ms>.<ext>`. Files must be JPEG, PNG or WebP and under 5 MB.
- **Orders.**
  - Online payment uses `create-xendit-payment` and the 15-minute "Waiting for Payment" window.
  - Reviews go through `submit_order_reviews`. The store rating, the per-product ratings and editing an existing review all work as in the app.
  - Support reports carry `order_id` and `delivery_id`.
- **Admin.**
  - Drone control is Recharge only, on the single drone DRN-001.
  - Weather overrides last 2 hours.
  - The radar reads `drone_telemetry`.
  - Activity shows `delivery_safety_checks` and recent sign-ups, as the app's Reports page does.

## Where things are

| Path | What |
|---|---|
| `src/pages/landing.tsx`, `about.tsx`, `team.tsx` | Public pages: the hero, About Us, Meet the Team |
| `src/data/team.ts` | Team members shown on /team (names, roles, optional photos in `public/team/`) |
| `src/pages/user`, `vendor`, `admin` | One folder per portal |
| `src/pages/shared` | Order details and chat, notifications, profile, help |
| `src/layouts/nav.ts` | Sidebar navigation for each role, carried over from the app's shells |
| `src/data/api.ts` | The data contract; `live-api.ts` implements it on the app's Supabase project |
| `src/lib/fees.ts` | Port of `delivery_fee_calculator.dart` |
| `src/components/forgeui` | ForgeUI components, adapted (see below) |

Routes match the app's GoRouter paths (`/user/shop`, `/vendor/orders`, `/admin/routes/no-fly-zones`, …), and each role is redirected out of the others' areas the same way.

## Components

- **ForgeUI**: Animated Tabs, Animated OTP, Notification Center, Progress Stack, Stats Card, Text Shimmer, Text Reveal and Text Morph, installed with `npx shadcn add @forgeui/<name>` and then adapted. They now use lucide icons, plain `<img>` instead of `next/image`, and AeroDrop colours, with reduced-motion fallbacks and keyboard access. The remaining ForgeUI components need a Pro token.
- **Uiverse** (MIT, [uiverse-io/galaxy](https://github.com/uiverse-io/galaxy)): the toggle switch, ring spinner, bounce dots and the ripple CTA button, recoloured. Credits are in `src/index.css` and `src/components/brand.tsx`.
- **Radix** dialogs for focus trapping, **react-leaflet** with OpenStreetMap for the maps, **Recharts** for charts.

## App screenshots

Every phone image on the landing and About pages (`public/app/*.webp`) is a real screen of the Flutter app, not a mock-up. Each has a light and a dark version, and the page shows the one matching its theme.

To re-render them after the app changes (needs Flutter and Google Chrome):

```bash
npm run app-shots
```

`tools/app-shots/` holds the pipeline:

| Part | What it does |
|---|---|
| `harness/` | A tiny Flutter web app that imports AeroDrop by path and runs `AeroDropApp` unmodified. It signs in through the app's own `AuthNotifier.login` and `verifyLoginOtp`. `?inset=1` gives it iPhone safe areas. |
| `mock/` | A local stand-in for Supabase: a small PostgREST with embedded selects and filters, auth, and the RPCs the app calls. It serves sample rows so the app can be captured without touching the real database. |
| `export.mjs` | Drives the app in headless Chrome with the clock pinned to 11:42 Manila time, then writes the WebP files. |

The app's source and its `pubspec.lock` are never modified.

Two app screens have light-theme bugs, so the website doesn't show them:
- `lib/core/widgets/delivery_card.dart` draws the order title and percentage in `Colors.white`. On the light home screen they're invisible, so Home isn't in the hero.
- `lib/features/auth/verification_page.dart` always paints a dark background (`bgGradientDark`), while its text follows the theme, so it's unreadable in light mode.

## Before going live

- Set `VITE_PLAY_STORE_URL` to the real listing once the app is published.
- In Supabase Auth, add the website's domain to the allowed redirect URLs, including `https://<your-domain>/auth/callback` for Google sign-in. Enable the Google provider if it is not already on.
- The storage buckets `avatars`, `vendor-logos` and `product-images` must be public-read, as the app expects.
