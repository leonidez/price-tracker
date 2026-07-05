# Price Tracker — Design

## What it is
Personal price-tracking app. Scan a product barcode in a physical store, pick the store,
and the backend tracks that product's price on the store's website, sending a push
notification when a user-defined rule trips (percent off, dollars off, or below a target
price). Single user; personal MVP.

## Architecture
- `mobile/` — Expo (React Native, TypeScript) app: barcode scanning, watch management,
  push notifications.
- `backend/` — Rails 8 API (SQLite + Solid Queue): store adapters, scheduled price checks,
  rule evaluation, Expo push sending. Auth is a single shared bearer token (personal app).

Mobile ⇄ Rails over JSON (contract in docs/API.md once written). Rails → store websites /
unofficial APIs on a schedule (2–4 checks/day, jittered). Rails → Expo Push API for
notifications (no APNs/FCM setup needed).

## Core flow
1. Scan barcode (UPC-A / EAN-13 / UPC-E, normalized to GTIN-13).
2. Pick store from a dropdown (the active `stores` rows).
3. Backend resolves barcode + store → product page (adapter-specific) and returns a
   confirmation card: title, image, current price, verified flag.
4. User confirms, sets alert rules → watch created with a baseline price (defaults to the
   current price; user-editable — matters when an item is scanned while already on sale).
5. A recurring job re-checks each listing, appends price history, evaluates rules, and
   pushes alerts.

Fallback when resolution fails: manual pairing — paste any product URL; a generic
extractor tracks it.

## Data model (money is always integer cents + a currency string)
- products: gtin13 (unique), barcode_raw, name, brand, image_url
- stores: name, slug (unique), domain, adapter, config (json), active
- listings: product×store (unique pair), url, store_ref (json, e.g. Target TCIN),
  status (active / parse_failed / blocked / archived), consecutive_failures, last_checked_at
- price_points: listing, price_cents, currency, in_stock, checked_at, source
- watches: listing, baseline_price_cents, armed (bool, for alert re-arm), active
- alert_rules: watch, kind (percent_drop / amount_drop / below_price), value_pct or value_cents
- notifications: watch, price_point, kind (price_alert / parse_failure),
  notified_price_cents, sent_at, push_status
- devices: expo_push_token (unique), platform, active

## Store adapters
Each store row names an adapter class (`StoreAdapters::Walmart`, etc.) with two duties:
- resolve(gtin13, hint) — barcode → candidate product page. Strategies tried in order;
  candidates verified by comparing the page's GTIN (JSON-LD gtin12/gtin13) to the scan.
- check(listing) — current price/stock via the cheapest reliable method.

Generic price-extraction ladder (used by adapters and the generic URL fallback):
JSON-LD Product/offers → OpenGraph/microdata meta tags → per-store CSS selector from
stores.config → give up (mark parse_failed, notify the user — silent failure is worse
than admitting it).

v1 adapters: Walmart (site search + __NEXT_DATA__/JSON-LD), Target (unofficial RedSky
JSON API with pricing_store_id for store-specific prices; HTML fallback), Generic
(check-only, works on any URL). Phase 2 (deferred): Michaels, Cost Plus World Market —
they need a name-search resolution tier and an unknown-barcode manual-name flow
(World Market is heavily private-label). Kroger / Best Buy have official free APIs —
possible later adds.

## Alert semantics
Rules within a watch are OR'd. On each new price point, with baseline B and price P:
- below_price: P ≤ value
- percent_drop: P ≤ B × (1 − pct/100)
- amount_drop: B − P ≥ value

Notify on the false→true transition only. Re-notify only if P drops below the price last
notified about, or the watch re-armed (a check where no rule triggered) since. Never
re-notify a steady price. Parse failures notify once, on the transition into parse_failed.

## Operational constraints
- Scrape jobs run from a home IP (Walmart/Target aggressively block datacenter IPs);
  low frequency with jitter; realistic browser headers.
- RedSky endpoints are unofficial and may drift — endpoint keys/IDs live in stores.config,
  not code.
- Tests never hit live sites: checked-in HTML/JSON fixtures only. Live smoke tests are
  manual rake tasks (probe:*), never run in CI.

## Phasing
Backend core (console-testable) → rule engine → scheduled checks → REST API → Expo push →
mobile read screens → create/edit flows → push wiring → barcode scanning → home deployment
(Tailscale).
