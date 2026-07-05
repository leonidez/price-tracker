# Price Tracker — Mobile

Expo (React Native, TypeScript) app. Navigation with **expo-router**; server
state with **React Query**. See [`../docs/API.md`](../docs/API.md) for the API
contract and [`../CLAUDE.md`](../CLAUDE.md) for conventions.

## Requirements

- Node (LTS) + npm
- The [Expo Go](https://expo.dev/go) app on your phone (dev), or an EAS dev
  build (needed for push — see #15)

## Environment

Config comes from `EXPO_PUBLIC_*` env vars (inlined at build time). Copy the
example and edit it — `.env` is git-ignored:

```bash
cp .env.example .env
```

- `EXPO_PUBLIC_API_URL` — backend base URL. In dev, use your computer's **LAN
  IP** (not `localhost`) so the phone on the same Wi-Fi can reach it, e.g.
  `http://192.168.1.10:3000`. Expo Go permits plain http in dev.
- `EXPO_PUBLIC_API_TOKEN` — must match the backend's `API_TOKEN`.

## Run

```bash
npm install
npx expo start        # scan the QR code with Expo Go
```

Start the backend too (`cd ../backend && bin/dev`). On the **Settings** tab, tap
**Test connection** — it hits `/api/v1/ping` and shows success or a readable
error (e.g. a wrong token).

## Checks

```bash
npm run typecheck     # tsc --noEmit (strict)
npm run lint          # eslint (expo config) + prettier --check
npm run format        # prettier --write
```

## Layout

- `src/app/` — expo-router routes (`index` = Watches tab, `settings` = Settings tab).
- `src/api/` — `client.ts` (fetch wrapper + `ApiError`), `types.ts` (mirrors
  `docs/API.md`), `endpoints.ts` (one function per endpoint).
- `src/lib/` — helpers (`money.ts` — `formatCents`).

## CI

`.github/workflows/mobile.yml` runs typecheck + lint on every push/PR touching
`mobile/**`.
