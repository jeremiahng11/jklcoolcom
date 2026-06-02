# Coolify Companion — push server

A small **Fastify + firebase-admin** service that watches a Coolify instance and
sends **FCM push notifications** to Coolify Companion devices when:

- a resource goes **unhealthy / down** (healthy → degraded/unhealthy/exited), and
- a **deployment finishes / fails / is cancelled**.

Pushes include a data payload (`type`, `uuid`) so the app **deep-links** to the
right screen and records them in its in-app inbox.

## How it works

- Devices register their FCM token via `POST /register`.
- The server polls Coolify every `POLL_SECONDS` (`/resources` for health,
  `/deployments/applications/{uuid}` for deploy status), diffs against the last
  state, and sends FCM messages on changes.
- The **first** poll seeds state silently (no spam about pre-existing state).
- Invalid/expired tokens are pruned automatically.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET  | `/health` | liveness |
| GET  | `/status` | token count, watched Coolify, poll interval |
| POST | `/register` | `{ "token": "…" }` — register a device |
| POST | `/unregister` | `{ "token": "…" }` |
| POST | `/test` | `{ "title","body","data" }` — send a test push to all devices |

## Configure

Copy `.env.example` → `.env` and set:

- `COOLIFY_URL`, `COOLIFY_TOKEN` — your instance + an API token (read scope).
- **Firebase service account** (one of):
  - `FIREBASE_SERVICE_ACCOUNT_BASE64` — `base64 -w0 service-account.json`
    (get the JSON from Firebase → Project settings → Service accounts →
    *Generate new private key*). Easiest for env-only hosts.
  - or `GOOGLE_APPLICATION_CREDENTIALS` — path to the JSON file.
- `POLL_SECONDS` (default 30), optional `REGISTER_SECRET`.

**Never commit the service-account JSON** — it's in `.gitignore`.

## Run

Local:

```bash
npm install
cp .env.example .env   # fill it in
node --env-file=.env --import tsx src/index.ts   # or: npm run dev
```

Docker:

```bash
docker build -t coolify-companion-push .
docker run -d --name coolify-companion-push --restart unless-stopped \
  -p 8090:8090 -v "$PWD/data:/app/data" --env-file .env \
  coolify-companion-push
```

**Deploy on Coolify** (recommended): add this folder as an app (Dockerfile build),
set the env vars above, expose port 8090, and add a persistent volume at
`/app/data`. Optionally give it a domain via a Cloudflare Tunnel so the app can
reach `/register` from anywhere.

## Connect the app

In Coolify Companion: **Settings → Notifications → Notification server URL** →
the server's URL (e.g. `https://push.yourdomain.com`). With push enabled, the
app registers its token automatically. Trigger a deploy or stop a resource to
see a notification.

## Notes / limits

- Single-tenant: it watches **one** Coolify (the one in `COOLIFY_URL`) and pushes
  to all registered devices. Run one instance per Coolify.
- Token store is a JSON file under `DATA_DIR` — fine for small fleets; swap for
  SQLite/Drizzle if you need scale.
- Health alerts rely on Coolify's `status` strings; deploy alerts on the
  per-app deployment history.
