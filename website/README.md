# AeroDrop website

The web front end for AeroDrop: a landing page for the app, plus customer, vendor and admin portals that use the same Supabase backend as the Flutter app. It is a separate React project; it does not embed or link to the Flutter build in `../web`.

## Run it

```bash
cd website
npm install
cp .env.example .env   # required: the app's Supabase URL and anon key
npm run dev            # http://localhost:5173
```

`npm run build` writes a static site to `dist/`. It is set up for Vercel (see [Deploy to Vercel](#deploy-to-vercel)); any other static host works if every path falls back to `index.html`.

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
  - `/complete-profile` for accounts without a phone number.
  - Philippine mobile numbers only, on sign-up, complete profile and the profile page. +63 is fixed in front, the field takes digits only and stops at 10 (9XX XXX XXXX). Pasted 09… or +63… numbers are trimmed, and the number is stored as +639XXXXXXXXX, as the app does.
  - The 6-character password minimum. Sign-up shows a strength bar and tips (length, mixed case, a number, a symbol) and warns about common passwords or ones containing the person's name or email. The bar advises; only the minimum is enforced, as in the app.
  - Verify later (migration 35). With Supabase's "Confirm email" off, sign-up signs people straight in. Until the email is verified, customers and vendors see a banner, and the database refuses their orders. **Verify email** on the banner or on the profile emails a 6-digit code and opens the code card. Entering it sets `users.email_verified_at`. An emailed-code sign-in in the app also counts, through a trigger. Unverified accounts sign in with just their password; verified accounts still confirm each sign-in with a code. If "Confirm email" is still on, sign-up falls back to asking for the code straight away.
  - Real email addresses only (migration 34). Before an account is made, the app and the website both call the `check-email` Edge Function. It refuses malformed addresses, domains that don't exist or can't receive mail (DNS MX lookup), throwaway inboxes and common typos, which get a "Did you mean …?" fix. A database trigger refuses the same throwaway and typo domains even if the auth API is called directly, and the emailed code still has to be entered.
- **Storage.** The app's buckets and paths: `avatars/<uid>/avatar.<ext>`, `vendor-logos/<uid>/logo.<ext>` (or `business_logo.<ext>` at sign-up), and `product-images/<uid>/prod_<ms>.<ext>`. Files must be JPEG, PNG or WebP and under 5 MB.
- **Orders.**
  - Online payment uses `create-xendit-payment` and the 15-minute "Waiting for Payment" window.
  - Reviews go through `submit_order_reviews`. The store rating, the per-product ratings and editing an existing review all work as in the app.
  - Support reports carry `order_id` and `delivery_id`, and use the app's categories (`general`, `order_issue`, `delivery_issue`, `account`, `other`).
- **Support conversations** (migrations 28 to 30).
  - Every report is a thread at `/user/help/:id`, `/vendor/help/:id` and `/admin/support/:id`. The report's own message opens it; replies live in `support_messages`.
  - Each message can carry text and up to three JPEG, PNG or WebP photos under 5 MB. Photos go to the private `support-attachments` bucket at `<report_id>/<uuid>.<ext>` and are shown through signed URLs that last an hour.
  - A reporter replying to a resolved report reopens it, and admins are always notified of a reopen. Both are done by the database trigger, not the website.
  - Opening a thread calls `mark_support_messages_read`, which also clears that report's bell notifications. Support notifications open the thread.
- **Terms.** The sign-up checkbox links to the Terms and Privacy Policy, which can be read while signed out. Its time goes into the auth metadata and is copied to `users.terms_accepted_at` at the first signed-in session, as the app does. Both profile menus link to the Terms and the Privacy Policy.
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

## Deploy to Vercel

`vercel.json` holds everything Vercel needs: the Vite preset, `npm ci`, the `dist` output, a fallback so deep links such as `/admin/drones` and `/auth/callback` load, security headers, and long-lived caching for hashed assets.

1. Commit and push the repository (it is on GitHub as `Rzenz/AeroDrop`). `.env` is git-ignored, so keys never reach the repository.
2. In Vercel, choose **Add New → Project** and import the repository.
3. Set **Root Directory** to `website`. Leave the build settings as detected; they come from `vercel.json`.
4. Under **Environment Variables**, add these for Production and Preview:

   | Name | Value |
   |---|---|
   | `VITE_SUPABASE_URL` | `https://<project-ref>.supabase.co` |
   | `VITE_SUPABASE_ANON_KEY` | The publishable key (`sb_publishable_…`) or legacy `anon` key |
   | `VITE_PLAY_STORE_URL` | Optional. The Google Play listing |

   If you connected Supabase through Vercel's Supabase integration instead, its `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` (or `SUPABASE_URL` and `SUPABASE_ANON_KEY`) are picked up automatically. The `VITE_` names win if both are set. The integration must be linked to the app's existing project, not a new one. The build log prints `[aerodrop] Supabase project: <ref>.supabase.co` so you can check.

5. Deploy. The build stops with a clear message if a Supabase value is missing or if the key is a secret key. The service-role key and JWT secret are never read.
6. In Supabase, go to **Authentication → URL Configuration**:
   - Set **Site URL** to the Vercel domain.
   - Add `https://<your-domain>/auth/callback` to **Redirect URLs**.
   - For preview deployments, also add `https://*-<team>.vercel.app/auth/callback`.

`VITE_` variables are baked in at build time. After changing one in Vercel, redeploy for it to take effect.

The build writes a Content-Security-Policy into `index.html` that names the configured Supabase project. If the project URL changes (for example, to a custom domain), just redeploy and the policy follows.

The CLI works too: from `website/`, run `npx vercel` for a preview or `npx vercel --prod` for production. Set the variables first with `npx vercel env add`.

## Before going live

- Email verification (migration 35), in this order:
  1. Apply migration 35. Its backfill marks every account that exists now as verified.
  2. Turn off **Authentication → Providers → Email → Confirm email** so new accounts are signed in straight away.
  3. Make sure the **Magic Link** email template includes `{{ .Token }}`: the Verify email card and the sign-in code both use it.

  The Flutter app was not changed for this. With "Confirm email" off, its own sign-up screen still waits for a code that Supabase no longer sends. Its existing code-at-sign-in still verifies the email.

- Set up custom SMTP so sign-up and sign-in codes reach everyone. Supabase's built-in sender only emails members of the project's team, two messages an hour; every other address is refused ("Email address not authorized"), so the account is created but no code arrives. In Supabase, open **Authentication → Emails → SMTP Settings**, enable custom SMTP and enter a provider's details (Gmail with an App Password, Brevo, Resend, Postmark, AWS SES…). Then raise **Authentication → Rate Limits → emails per hour** (custom SMTP starts at 30). The **Confirm signup**, **Magic Link** and **Reset Password** templates must include `{{ .Token }}`, since both clients ask for the 6-digit code.

- Apply migration 34 and deploy the email check. Until the function is deployed, both clients carry on without it (the emailed code still applies):
  ```bash
  supabase db push
  supabase functions deploy check-email --no-verify-jwt
  ```
  `--no-verify-jwt` is needed because people call it before they have an account. To block another domain, add a row to `public.blocked_email_domains`.

- Set `VITE_PLAY_STORE_URL` to the real listing once the app is published.
- In Supabase Auth, add the website's domain to the allowed redirect URLs, including `https://<your-domain>/auth/callback` for Google sign-in. Enable the Google provider if it is not already on.
- The storage buckets `avatars`, `vendor-logos` and `product-images` must be public-read, as the app expects.
