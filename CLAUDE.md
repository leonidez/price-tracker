# Price Tracker — agent instructions

Monorepo: `backend/` Rails 8 API (Ruby, minitest, rubocop-rails-omakase), `mobile/`
Expo/React Native (TypeScript strict, eslint + prettier), `docs/` design + contracts.

Read `docs/DESIGN.md` before implementing any issue. The API contract lives in
`docs/API.md` — backend and mobile must both conform to it; update it in the same PR
as any contract change.

Conventions:
- Money is always integer cents (`*_cents`) with an explicit currency; never floats.
- Barcodes are stored normalized as GTIN-13 strings.
- No live HTTP in tests — use checked-in fixtures under `backend/test/fixtures/http/`.
  Live smoke tests are manual rake tasks (`probe:*`), never run in CI.
- Backend: `bin/rails test` and `bin/rubocop` must pass.
- Mobile: `npm run typecheck` and `npm run lint` must pass.
- Implement issues in numeric order; each issue lists its dependencies.

Remote implementation (Claude Code on the web):
- Issues are implemented in cloud sandboxes: Linux only, no physical device, no macOS,
  restricted networking from datacenter IPs. Acceptance criteria in issues are tagged:
  - **Agent-verified** — make these pass in the sandbox before opening the PR
    (tests, rubocop, typecheck, lint, files/docs committed).
  - **Human-verified locally** — require a physical phone, a home-IP network, or the
    home server. Implement the code for them, but do NOT claim them as done or check
    them off; copy them into the PR description under a "Needs local verification"
    heading instead.
- Never run live `probe:*` tasks in the sandbox — store sites block datacenter IPs,
  so a failure there says nothing about the code.
