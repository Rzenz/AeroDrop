#!/usr/bin/env bash
# Re-renders the landing page's app screenshots from the real Flutter app.
# Usage (from website/): npm run app-shots
set -euo pipefail
cd "$(dirname "$0")"

# The app loads images with unprefixed asset paths, so the harness needs its
# own copy of the app's assets (gitignored).
rm -rf harness/assets && cp -R ../../../assets harness/assets

(cd harness && flutter pub get >/dev/null && flutter build web --release \
  --dart-define=SUPABASE_URL=http://localhost:7070 \
  --dart-define=SUPABASE_ANON_KEY=mock-anon-key)

export MOCK_NOW="${MOCK_NOW:-$(node -e "console.log(Date.parse('2026-11-05T11:42:00+08:00'))")}"
node mock/server.mjs &
MOCK_PID=$!
trap 'kill $MOCK_PID' EXIT
for _ in $(seq 1 20); do curl -s -o /dev/null http://localhost:7070/ && break; sleep 0.5; done

node export.mjs
