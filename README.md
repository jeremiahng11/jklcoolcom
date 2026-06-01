# Coolify Companion

A Flutter mobile companion app for [Coolify](https://coolify.io) — the open-source,
self-hostable PaaS. Connect one or more Coolify instances (localhost or cloud) and
manage **and** monitor your applications, databases, services, deployments, servers
and projects from your phone, using the full Coolify v1 REST API.

## Features

- **Multiple accounts** — connect as many Coolify instances as you like (a home
  server on `localhost`, a VPS, Coolify Cloud, …). Each account has its own accent
  colour so they're easy to tell apart; switch the active account from the avatar in
  the app bar. API tokens are stored in the OS secure storage (Keychain / Keystore).
- **Dashboard** — aggregated health across every resource with a healthy/degraded/down
  rollup, per-server reachability, a "needs attention" list, and quick counts. Polls
  automatically every ~15 s while the app is in the foreground.
- **Resources** — tabbed Applications / Databases / Services with search and
  colour-coded status badges (parses Coolify's `running:healthy`, `degraded`,
  `exited`, … strings).
- **Full creation**
  - **Apps**: public Git repo, private repo (deploy key or GitHub App), Dockerfile,
    or pre-built Docker image.
  - **Databases**: PostgreSQL, MySQL, MariaDB, MongoDB, Redis, KeyDB, Dragonfly,
    ClickHouse.
  - **Services**: one-click catalogue or a pasted `docker-compose.yml`.
- **Application detail** — start / stop / restart / deploy / force-rebuild, domains,
  source & build config, an environment-variable editor (build-time / preview /
  literal / multiline / secret flags), deployment history, **live log tailing**, and
  inline settings editing with a danger zone.
- **Databases & services** — lifecycle controls, connection info, env vars, editable
  settings, delete.
- **Deployments** — watch running deployments (with cancel), open a deployment to see
  its **live logs**, and browse per-app history.
- **Servers / Projects / SSH keys / Team** — browse and manage, validate servers,
  create projects, add/remove private keys.
- **Theming** — modern Material 3, dark-first with a light / system toggle.

## Running locally

Requirements: Flutter 3.44+ (Dart 3.12+).

```bash
flutter pub get
flutter run            # pick an Android/iOS device or simulator
```

On first launch you'll be asked to connect an instance:

1. **Label** — any name, e.g. "Home server".
2. **Instance URL** — `https://coolify.example.com`, or `localhost:8000` for a local
   instance. The `/api/v1` suffix is added automatically; local hosts default to
   `http`.
3. **API token** — create one in Coolify under **Keys & Tokens**.
4. Tap **Test connection** to verify (it resolves your team and Coolify version), then
   **Add account**.

### API token scopes

Grant the scopes you need when creating the token in Coolify:

| Scope            | Needed for                                              |
| ---------------- | ------------------------------------------------------- |
| `read`           | Listing and viewing resources                           |
| `write`          | Creating / editing / deleting resources & env vars      |
| `deploy`         | Triggering deployments, start/stop/restart              |
| `read:sensitive` | Seeing secret env-var values and DB connection strings  |
| `root`           | Bypasses all checks (use with care)                     |

The app surfaces a clear message when a request fails because the token lacks a scope.

## Live server metrics (optional)

Coolify's API doesn't expose realtime CPU / memory / disk, so live metrics come
from a tiny **on-host agent** included in [`agent/`](agent/). It reads `/proc`
and serves token-protected JSON; the app polls it and shows a Live card on the
dashboard (per-core CPU bars, CPU/RAM sparklines, disk, uptime).

Quick start on the host (Debian/Raspberry Pi — full guide in
[`agent/README.md`](agent/README.md)):

```bash
sudo mkdir -p /opt/coolify-companion-agent
sudo cp agent/agent.py /opt/coolify-companion-agent/
TOKEN=$(openssl rand -hex 24); echo "$TOKEN"   # use this in the app
sudo cp agent/coolify-companion-agent.service /etc/systemd/system/
sudo sed -i "s/CHANGE_ME/$TOKEN/" /etc/systemd/system/coolify-companion-agent.service
sudo systemctl daemon-reload && sudo systemctl enable --now coolify-companion-agent
```

Then in the app: **edit your account → Live metrics** → set the agent URL
(`http://<host-ip>:8088`) and the token. A `Dockerfile` is provided for running
the agent as a container (e.g. via Coolify) instead.

## Project structure

```
lib/
  api/         CoolifyClient (all endpoints) + typed ApiException
  models/      immutable models + ResourceStatus parser
  providers/   Riverpod providers (instances, client, theme, resources, logs, …)
  services/    InstanceStore (secure token storage + prefs)
  screens/     onboarding, dashboard, resources + details, create flows,
               deployments, servers, projects, settings
  widgets/     status badge, resource card, log console, env-var editor, …
  theme/       Material 3 dark/light theme
```

- **State**: [Riverpod 3](https://riverpod.dev)
- **Routing**: [go_router](https://pub.dev/packages/go_router) (bottom-nav shell)
- **Networking**: `http`
- **Storage**: `flutter_secure_storage` (tokens) + `shared_preferences` (metadata)

## Tests

```bash
flutter test       # status parser, URL normalisation, model round-trip, widget test
flutter analyze    # clean
```

## Notes

- Lifecycle endpoints (`/start`, `/stop`, `/restart`, `/deploy`, `/validate`) are
  called via GET, which the Coolify API accepts.
- Destructive actions are confirmed before running.
- Push notifications are not included in this version; the dashboard polls for near
  real-time health while the app is open.

## License

MIT
