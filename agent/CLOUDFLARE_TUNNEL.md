# Cloudflare Tunnel — expose the metrics agent on your own domain

Cloudflare Tunnel securely exposes a local service to the internet **without
opening ports or port-forwarding**. It creates an encrypted tunnel from your
device to Cloudflare's edge, so you can reach the metrics agent from anywhere
(e.g. `https://metrics.yourdomain.com`).

> The in-app guide (**Settings → Live metrics setup → Access from anywhere**)
> mirrors this document with copy buttons.

## Prerequisites

- A Cloudflare account with your domain on **Cloudflare DNS**.
- SSH access to the server (Raspberry Pi / Linux host).
- The metrics agent already running locally (e.g. on port `8088`).

## 1. Install cloudflared

```bash
# Raspberry Pi (aarch64 / arm64):
wget -O /tmp/cloudflared \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
# Pi 3 / Zero (armv7):  ...releases/latest/download/cloudflared-linux-arm
# x86_64:               ...releases/latest/download/cloudflared-linux-amd64

sudo mv /tmp/cloudflared /usr/local/bin/
sudo chmod +x /usr/local/bin/cloudflared
cloudflared --version
```

## 2. Authenticate

```bash
cloudflared tunnel login
```

Opens a browser to log in and pick your domain; writes credentials to
`~/.cloudflared/<TUNNEL_ID>.json`.

## 3. Create a tunnel

```bash
cloudflared tunnel create my-tunnel
cloudflared tunnel list          # note the Tunnel ID
```

## 4. Configure it

`~/.cloudflared/config.yml`:

```yaml
tunnel: <YOUR_TUNNEL_ID>
credentials-file: /home/<user>/.cloudflared/<YOUR_TUNNEL_ID>.json

ingress:
  - hostname: metrics.yourdomain.com
    service: http://localhost:8088
  - service: http_status:404
```

## 5. Route DNS (creates the CNAME)

```bash
cloudflared tunnel route dns my-tunnel metrics.yourdomain.com
```

This adds a **CNAME** pointing the hostname at the tunnel
(`<id>.cfargotunnel.com`). **Do not** add an `A` record to your home IP — that
causes a `503 "no available server"`.

## 6. Test

```bash
cloudflared tunnel run my-tunnel
```

Visit `https://metrics.yourdomain.com`.

## Auto-start on reboot (systemd)

```bash
sudo tee /etc/systemd/system/cloudflared-tunnel.service > /dev/null << 'EOF'
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=<user>
ExecStart=/usr/local/bin/cloudflared tunnel run my-tunnel
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now cloudflared-tunnel
sudo systemctl status cloudflared-tunnel
```

## Troubleshooting

- **DNS not resolving** — Cloudflare → DNS should show a **CNAME** to
  `<id>.cfargotunnel.com`. Allow a few minutes to propagate.
- **`503 "no available server"`** — the local service isn't reachable. Check
  `curl http://localhost:8088/health` and that the `service:` URL/port in
  `config.yml` matches.
- **Tunnel not connecting** — `sudo journalctl -u cloudflared-tunnel -n 50`;
  confirm the credentials file referenced in `config.yml` exists.

## Useful commands

```bash
cloudflared tunnel list
cloudflared tunnel info my-tunnel
sudo systemctl restart cloudflared-tunnel
sudo journalctl -u cloudflared-tunnel -n 50 -f
cloudflared tunnel delete my-tunnel
```

## Security

Traffic is encrypted end-to-end and no router ports are opened. The agent token
still gates access — keep it long, and optionally add **Cloudflare Access** in
front for an extra auth layer.

## Local-only alternative

If you only need access on the same Wi-Fi, skip the tunnel and point the app at
the agent's LAN address directly:

```
http://192.168.x.x:8088
```
