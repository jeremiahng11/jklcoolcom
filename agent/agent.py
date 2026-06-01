#!/usr/bin/env python3
"""Coolify Companion metrics agent.

A tiny, zero-dependency (stdlib only) HTTP service that exposes live host
metrics — CPU %, memory, disk and uptime — as JSON for the Coolify Companion
app. Designed for a Raspberry Pi / Linux host running Debian Bookworm.

Run it with systemd (see coolify-companion-agent.service) or Docker (see
Dockerfile). Configuration via environment variables:

  METRICS_TOKEN   shared secret; clients must send `Authorization: Bearer <it>`
                  (required — the agent refuses to start without it)
  METRICS_PORT    listen port (default 8088)
  METRICS_BIND    bind address (default 0.0.0.0)
  PROC_PATH       /proc location (default /proc; set to /host/proc in Docker)
  DISK_PATH       filesystem to report (default /; set to /host/root in Docker)

Endpoint:
  GET /metrics -> {cpu_percent, mem:{used,total,percent}, disk:{...},
                   uptime_seconds, load:[1,5,15], hostname, cores}
  GET /health  -> "OK" (no auth)
"""

import json
import os
import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PROC = os.environ.get("PROC_PATH", "/proc")
DISK = os.environ.get("DISK_PATH", "/")
TOKEN = os.environ.get("METRICS_TOKEN", "")
PORT = int(os.environ.get("METRICS_PORT", "8088"))
BIND = os.environ.get("METRICS_BIND", "0.0.0.0")

_prev_cpu = None
_lock = threading.Lock()


def _read_all_cpu():
    """Read overall + per-core CPU times from /proc/stat.

    Returns {"total": (idle, total), 0: (idle, total), 1: ...}.
    """
    res = {}
    with open(f"{PROC}/stat") as f:
        for line in f:
            if not line.startswith("cpu"):
                break
            parts = line.split()
            vals = [int(x) for x in parts[1:]]
            idle = vals[3] + (vals[4] if len(vals) > 4 else 0)  # idle + iowait
            key = "total" if parts[0] == "cpu" else int(parts[0][3:])
            res[key] = (idle, sum(vals))
    return res


def cpu_stats():
    """Return (overall_percent, [per_core_percent, ...])."""
    global _prev_cpu
    with _lock:
        cur = _read_all_cpu()
        if _prev_cpu is None:
            time.sleep(0.2)
            a = cur
            b = _read_all_cpu()
        else:
            a = _prev_cpu
            b = cur
        _prev_cpu = b

    def pct(k):
        if k not in a or k not in b:
            return 0.0
        idle_d = b[k][0] - a[k][0]
        total_d = b[k][1] - a[k][1]
        if total_d <= 0:
            return 0.0
        return round(max(0.0, min(100.0, 100.0 * (1 - idle_d / total_d))), 1)

    overall = pct("total")
    cores = [pct(i) for i in sorted(k for k in b if isinstance(k, int))]
    return overall, cores


def mem():
    info = {}
    with open(f"{PROC}/meminfo") as f:
        for line in f:
            k, _, v = line.partition(":")
            info[k] = int(v.strip().split()[0]) * 1024
    total = info["MemTotal"]
    avail = info.get("MemAvailable", info.get("MemFree", 0))
    used = total - avail
    return {
        "total": total,
        "used": used,
        "percent": round(100.0 * used / total, 1) if total else 0.0,
    }


def disk():
    s = os.statvfs(DISK)
    total = s.f_blocks * s.f_frsize
    free = s.f_bfree * s.f_frsize
    used = total - free
    return {
        "total": total,
        "used": used,
        "percent": round(100.0 * used / total, 1) if total else 0.0,
    }


def uptime():
    with open(f"{PROC}/uptime") as f:
        return float(f.read().split()[0])


def loadavg():
    with open(f"{PROC}/loadavg") as f:
        return [float(x) for x in f.read().split()[:3]]


def collect():
    overall, per_core = cpu_stats()
    return {
        "hostname": socket.gethostname(),
        "cores": os.cpu_count() or 0,
        "cpu_percent": overall,
        "cpu_per_core": per_core,
        "mem": mem(),
        "disk": disk(),
        "uptime_seconds": int(uptime()),
        "load": loadavg(),
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # quiet

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Authorization")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/health"):
            self.send_response(200)
            self._cors()
            self.end_headers()
            self.wfile.write(b"OK")
            return

        if not self.path.startswith("/metrics"):
            self.send_response(404)
            self._cors()
            self.end_headers()
            return

        auth = self.headers.get("Authorization", "")
        token = auth[7:] if auth.startswith("Bearer ") else ""
        if token != TOKEN:
            self.send_response(401)
            self._cors()
            self.end_headers()
            self.wfile.write(b'{"error":"unauthorized"}')
            return

        try:
            body = json.dumps(collect()).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self._cors()
            self.end_headers()
            self.wfile.write(body)
        except Exception as e:  # noqa: BLE001
            self.send_response(500)
            self._cors()
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())


def main():
    if not TOKEN:
        raise SystemExit(
            "METRICS_TOKEN is required. Set it to a random secret and use the "
            "same value in the app."
        )
    server = ThreadingHTTPServer((BIND, PORT), Handler)
    print(f"Coolify Companion agent listening on {BIND}:{PORT} (proc={PROC}, disk={DISK})")
    server.serve_forever()


if __name__ == "__main__":
    main()
