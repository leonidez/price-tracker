# Price Tracker — API v1

The JSON API the mobile app consumes. This document is the **contract**: the
backend and the mobile app must both conform to it. Any change updates this doc
in the same PR.

## Conventions
- Base path: all endpoints live under `/api/v1`.
- **Auth**: every request must send `Authorization: Bearer <API_TOKEN>`. Missing
  or wrong token → `401 {"error":{"code":"unauthorized"}}`. (The health check
  `GET /up` is the only unauthenticated route.)
- Money is always **integer cents** (`*_cents`) with an explicit `currency`.
- Barcodes are normalized to **GTIN-13** strings.
- Request/response bodies are JSON; send `Content-Type: application/json`.

### Error envelope
All errors use:
```json
{ "error": { "code": "invalid_barcode", "message": "unrecognized barcode" } }
```
with a meaningful HTTP status. (`unauthorized` is the one minimal case with no
`message`.) Common codes: `unauthorized` (401), `not_found` (404),
`invalid` / `invalid_barcode` / `invalid_rules` / `parse_failed` / `blocked` /
`unsupported` / `configuration_error` / `parameter_missing` (422).

### Rules payload
A watch has one or more alert rules (OR'd). At least one is required when
creating a watch.

| kind           | field         | meaning                                  |
| -------------- | ------------- | ---------------------------------------- |
| `below_price`  | `value_cents` | notify when price ≤ `value_cents`        |
| `amount_drop`  | `value_cents` | notify when baseline − price ≥ `value_cents` |
| `percent_drop` | `value_pct`   | notify when price ≤ baseline × (1 − pct/100) |

```json
[
  { "kind": "below_price", "value_cents": 8000 },
  { "kind": "percent_drop", "value_pct": 25 },
  { "kind": "amount_drop", "value_cents": 500 }
]
```

---

## GET /stores
Active stores for the store picker. `supports_resolution` is false for the
generic "by URL" store.

**Response 200**
```json
[
  { "id": 1, "slug": "walmart", "name": "Walmart", "supports_resolution": true },
  { "id": 3, "slug": "generic", "name": "Other (by URL)", "supports_resolution": false }
]
```

---

## POST /resolutions
Resolve a scanned barcode at a store to a product page (synchronous; the app
shows a spinner).

**Request**
```json
{ "barcode": "036000291452", "symbology": "upc_a", "store_id": 1 }
```
`symbology` is optional (e.g. `"upc_e"` for the 8-digit form the scanner reports).

**Response 200**
```json
{
  "product": { "gtin13": "0036000291452", "name": "Acme Cola 12pk", "image_url": "https://…/cola.jpg" },
  "resolution": {
    "url": "https://www.walmart.com/ip/acme-cola/123",
    "title": "Acme Cola 12pk",
    "image_url": "https://…/cola.jpg",
    "price_cents": 1299,
    "currency": "USD",
    "verified": true,
    "store_ref": { "us_item_id": "123" }
  }
}
```

**Errors**
- `422 invalid_barcode` — the barcode could not be normalized.
- `422 not_found` / `blocked` / `unsupported` — resolution failed (from the adapter).

---

## POST /watches
Create a watch. Two modes; both are transactional. Responds `201` with the full
watch JSON (same shape as `GET /watches/:id`).

### Mode 1 — from a resolution (barcode)
Echo the `resolution` object from `POST /resolutions`. `baseline_price_cents` is
optional (defaults to the resolution price — set it when the item was scanned
while already on sale).

**Request**
```json
{
  "barcode": "036000291452",
  "store_id": 1,
  "resolution": {
    "url": "https://www.walmart.com/ip/acme-cola/123",
    "title": "Acme Cola 12pk",
    "image_url": "https://…/cola.jpg",
    "price_cents": 1299,
    "currency": "USD",
    "verified": true,
    "store_ref": { "us_item_id": "123" }
  },
  "baseline_price_cents": 1299,
  "rules": [ { "kind": "below_price", "value_cents": 8000 } ]
}
```

### Mode 2 — from a URL (manual fallback)
`store_id` may be the generic store or a real store. The adapter's `check` runs
synchronously to capture the first price. `name` is optional.

**Request**
```json
{
  "url": "https://example.com/product",
  "store_id": 3,
  "name": "My Thing",
  "rules": [ { "kind": "percent_drop", "value_pct": 25 } ]
}
```

**Errors**
- `422 invalid_rules` — no rules provided.
- `422 invalid_barcode` — barcode could not be normalized (mode 1).
- `422 parse_failed` — the URL yielded no price (mode 2).
- `422 blocked` — the store blocked the request (mode 2).

---

## GET /watches
All watches, newest first.

**Response 200**
```json
[
  {
    "id": 12,
    "active": true,
    "armed": true,
    "baseline_price_cents": 1299,
    "product": { "name": "Acme Cola 12pk", "image_url": "https://…/cola.jpg", "gtin13": "0036000291452" },
    "store": { "slug": "walmart", "name": "Walmart" },
    "listing": { "url": "https://www.walmart.com/ip/acme-cola/123", "status": "active", "display_name": null },
    "latest_price": { "price_cents": 1199, "currency": "USD", "in_stock": true, "checked_at": "2026-07-05T18:00:00Z" },
    "rules": [ { "kind": "below_price", "value_cents": 8000, "value_pct": null } ],
    "sparkline": [ 1299, 1250, 1199 ]
  }
]
```
Name resolution: product name, else the listing `display_name`, else the URL
host. `latest_price` is `null` if there are no price points yet. `sparkline` is
the last 30 `price_cents`, oldest→newest.

---

## GET /watches/:id
The watch object above, plus history and recent notifications.

**Response 200** (added fields)
```json
{
  "…": "all fields from GET /watches",
  "price_points": [ { "price_cents": 1199, "in_stock": true, "checked_at": "2026-07-05T18:00:00Z" } ],
  "notifications": [ { "kind": "price_alert", "notified_price_cents": 1199, "sent_at": "2026-07-05T18:00:05Z" } ]
}
```
`price_points` is the last 90 (newest first); `notifications` the last 10.

**Errors**: `404 not_found`.

---

## PATCH /watches/:id
Update a watch. If `rules` is present it **replaces the full set** atomically.

**Request**
```json
{ "baseline_price_cents": 1100, "active": false, "rules": [ { "kind": "amount_drop", "value_cents": 300 } ] }
```

**Response 200**: the full watch JSON (as `GET /watches/:id`).

---

## DELETE /watches/:id
Destroys the watch. If no other watch references its listing, the listing (and
its price history) is destroyed too.

**Response 204** (no body). **Errors**: `404 not_found`.

---

## POST /devices
Register/refresh an Expo push token (upsert on the token).

**Request**
```json
{ "expo_push_token": "ExponentPushToken[xxxxxxxx]", "platform": "ios" }
```

**Response** `201` (new) or `200` (existing):
```json
{ "id": 4, "active": true }
```
Marks the device active and touches `last_seen_at`. `422 invalid` if the token
is missing.
