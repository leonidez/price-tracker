# Price Tracker

Personal price-tracking app: scan a product barcode in a physical store, pick the store,
and the Rails backend tracks that product's price on the store's website — sending a push
notification when a user-defined alert rule trips (percent off, dollars off, or below a
target price). Single user; personal MVP.

## Repo layout
- `backend/` — Rails 8 API (SQLite + Solid Queue): store adapters, scheduled price checks,
  rule evaluation, Expo push sending.
- `mobile/` — Expo (React Native, TypeScript) app: barcode scanning, watch management,
  push notifications.
- `docs/` — design docs and API contract.

## Development
Issues are **implemented in numeric order**; each issue lists its dependencies. See
[`docs/DESIGN.md`](docs/DESIGN.md) for the full design and
[`CLAUDE.md`](CLAUDE.md) for agent/contributor conventions.
