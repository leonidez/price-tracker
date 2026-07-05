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

## Push notifications (EAS dev build)

**Expo Go does not support remote push (since SDK 53).** You must build and
install an **EAS development build** on a physical phone. Budget time for the
one-time setup — it's the fiddliest step in the project.

### One-time setup

1. Install the EAS CLI and log in: `npm i -g eas-cli && eas login`.
2. `eas init` — links an Expo account/project and writes `extra.eas.projectId`
   into `app.json` (that id is what `getExpoPushTokenAsync` needs).
3. Build the dev client and install it on the phone:
   ```bash
   eas build --profile development --platform ios      # and/or android
   ```
   - **iOS** push credentials: let EAS manage them (`eas credentials`). This
     **requires an Apple Developer account**.
   - `eas.json`'s `development` profile sets `developmentClient: true`.
4. Start the dev server with `npx expo start --dev-client` and open the build.

### In-app wiring (already implemented)

- `registerForPush()` (`src/lib/push.ts`): requests permission →
  `getExpoPushTokenAsync({ projectId })` → `POST /devices`. Triggered after the
  first watch is created and from **Settings → Enable notifications** (which
  shows the current permission state). It does not ambush you at first launch.
- Foreground banner + sound via `setNotificationHandler`.
- Tap handling / deep link: a notification's `data.watch_id` navigates to
  `/watch/[id]` — both warm taps (response listener) and cold start
  (`getLastNotificationResponseAsync`).
- Android default notification channel is created on registration.

### Verification checklist (on the phone)

1. Dev build installed, backend running, phone registered (a `devices` row
   exists after tapping **Enable notifications**).
2. `cd ../backend && bin/rails push:test` → the notification arrives.
3. Create a watch with an already-met rule (e.g. `below_price` above the current
   price), then `bin/rails "check:listing[<id>]"` → **a price alert arrives and
   tapping it opens that watch's detail screen** (warm and cold start).

## Layout (routes)

- `src/app/(tabs)/` — `index` (Watches), `settings`.
- `src/app/watch/[id]`, `src/app/add-url`, `src/app/edit/[id]` — pushed screens.
- `src/lib/push.ts` — registration, foreground handler, deep-link hook.

## CI

`.github/workflows/mobile.yml` runs typecheck + lint on every push/PR touching
`mobile/**`.
