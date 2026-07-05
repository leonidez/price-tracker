# Price Tracker — Backend

Rails 8 API-only application (SQLite + Solid Queue) for the Price Tracker app.
See [`../docs/DESIGN.md`](../docs/DESIGN.md) for the overall design and
[`../CLAUDE.md`](../CLAUDE.md) for conventions.

## Requirements
- Ruby (see [`.ruby-version`](.ruby-version))
- SQLite 3

## Environment variables
- `API_TOKEN` (**required**) — the single shared bearer token. Every request to
  `/api/v1/*` must send `Authorization: Bearer $API_TOKEN`. In development, set it
  in your shell (e.g. `export API_TOKEN=dev-secret`); the test suite defaults it to
  `test_token`.

## Setup
```bash
cd backend
bin/setup            # installs gems, prepares the databases
```

## Running
Run the web server and the Solid Queue worker together via the Procfile:
```bash
bin/dev              # runs Procfile.dev (web + jobs) with foreman
```
Or individually:
```bash
bin/rails server     # web
bin/jobs             # Solid Queue worker (background jobs)
```
`Procfile.dev` defines the `web` and `jobs` processes. Background jobs run through
**Solid Queue**, which uses its own SQLite database (`storage/development_queue.sqlite3`).

## Auth smoke test
```bash
curl -i localhost:3000/api/v1/ping                                       # 401 unauthorized
curl -i -H "Authorization: Bearer $API_TOKEN" localhost:3000/api/v1/ping # {"ok":true}
curl -i localhost:3000/up                                                # 200 (no token needed)
```

## Tests & lint
```bash
bin/rails test       # minitest
bin/rubocop          # rubocop-rails-omakase
```

## CI
`.github/workflows/backend.yml` runs rubocop and the test suite on every push/PR that
touches `backend/**`.
