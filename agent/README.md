# Coolify Companion — metrics agent

A tiny, **zero-dependency** (Python stdlib only) HTTP service that exposes live
host metrics — **CPU %, memory, disk, uptime** — for the Coolify Companion app.
Coolify's API doesn't expose realtime metrics, so this agent runs on the host
(your Raspberry Pi) and the app polls it directly over your LAN.

## What it returns

`GET /metrics` (requires `Authorization: Bearer <METRICS_TOKEN>`):

```json
{
  "hostname": "raspberrypi",
  "cores": 4,
  "cpu_percent": 12.3,
  "mem":  { "total": 8188121088, "used": 1503238144, "percent": 18.4 },
  "disk": { "total": 250000000000, "used": 42000000000, "percent": 16.8 },
  "uptime_seconds": 84231,
  "load": [0.42, 0.31, 0.28]
}
```

`GET /health` → `OK` (no auth).

## Install on the Pi (systemd — recommended)

```bash
sudo mkdir -p /opt/coolify-companion-agent
sudo cp agent.py /opt/coolify-companion-agent/

# Pick a secret and put the SAME value in the app:
openssl rand -hex 24

sudo cp coolify-companion-agent.service /etc/systemd/system/
sudo sed -i "s/CHANGE_ME/<paste-your-secret>/" /etc/systemd/system/coolify-companion-agent.service

sudo systemctl daemon-reload
sudo systemctl enable --now coolify-companion-agent
systemctl status coolify-companion-agent
```

Test it:

```bash
curl -H "Authorization: Bearer <your-secret>" http://localhost:8088/metrics
```

Then in the app, edit your account and set:
- **Metrics agent URL:** `http://<pi-ip>:8088`  (e.g. `http://192.168.0.147:8088`)
- **Agent token:** the secret you generated

## Run with Docker instead

See the header of `Dockerfile` — you must bind-mount the host `/proc` and `/`
read-only and set `PROC_PATH` / `DISK_PATH` so it reports the **host**, not the
container.

## Configuration (env vars)

| Var | Default | Purpose |
| --- | --- | --- |
| `METRICS_TOKEN` | — (required) | Shared secret; the app sends it as a Bearer token |
| `METRICS_PORT`  | `8088` | Listen port |
| `METRICS_BIND`  | `0.0.0.0` | Bind address |
| `PROC_PATH`     | `/proc` | `/proc` location (set to `/host/proc` in Docker) |
| `DISK_PATH`     | `/` | Filesystem to report (set to `/host/root` in Docker) |

## Security

- The agent only **reads** system stats; it runs fine as a non-root user
  (`DynamicUser=yes` in the unit).
- Keep it on your LAN. The token gates access; use a long random value.
- To reach it from outside your network, front it with HTTPS via your reverse
  proxy rather than exposing port 8088 directly.
