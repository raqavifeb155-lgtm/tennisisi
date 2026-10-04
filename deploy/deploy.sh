#!/usr/bin/env bash
# Puts the game on a Debian/Ubuntu server behind nginx with a free HTTPS certificate
# (Telegram Mini Apps need HTTPS). Run from the unpacked archive:
#
#   sudo ./deploy.sh                      # first time, no domain: uses <ip>.sslip.io
#   sudo ./deploy.sh tennis.example.com   # first time, your own domain (A record -> this server)
#   sudo ./deploy.sh                      # again later: only replaces the game (new version)
#   sudo ./deploy.sh --update             # same, explicitly
#
# Safe for a server that already runs other things: it adds one nginx site and stops
# if ports 80/443 belong to something other than nginx.
set -euo pipefail
cd "$(dirname "$0")"
WEB_DIR=/var/www/tennis
SITE=/etc/nginx/sites-available/tennis

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as root: sudo ./deploy.sh" >&2
	exit 1
fi
if [ ! -f web/index.html ]; then
	echo "web/index.html not found: run this from the unpacked archive." >&2
	exit 1
fi

update_game() {
	mkdir -p "$WEB_DIR"
	cp -r web/. "$WEB_DIR/"
	# Older installs: serve the pre-compressed files (.gz) shipped in the archive.
	if [ -f "$SITE" ] && ! grep -q "gzip_static" "$SITE"; then
		sed -i 's/^\(\s*\)gzip on;/\1gzip on;\n\1gzip_static on;/' "$SITE"
	fi
	if command -v nginx >/dev/null; then
		nginx -t && systemctl reload nginx
	fi
	echo "Game updated in $WEB_DIR"
	grep -m1 -o "server_name [^;]*" "$SITE" 2>/dev/null | sed 's/server_name /Address: https:\/\//; s/$/\//' || true
}

if [ "${1:-}" = "--update" ] || { [ -z "${1:-}" ] && [ -f "$SITE" ]; }; then
	update_game
	exit 0
fi

for port in 80 443; do
	owner=$(ss -ltnpH "sport = :$port" 2>/dev/null | grep -o 'users:(("[^"]*' | head -1 | cut -d'"' -f2 || true)
	if [ -n "$owner" ] && [ "$owner" != "nginx" ]; then
		echo "Port $port is used by '$owner'. Stopping so nothing breaks." >&2
		echo "Use a separate domain/port, or put this site into that web server's config." >&2
		exit 1
	fi
done

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
	IP=$(curl -4 -s https://ifconfig.me || curl -4 -s https://api.ipify.org)
	DOMAIN="$(echo "$IP" | tr . -).sslip.io"
fi
echo "Domain: $DOMAIN"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx

mkdir -p "$WEB_DIR"
cp -r web/. "$WEB_DIR/"
sed "s/__DOMAIN__/$DOMAIN/g" nginx-tennis.conf > "$SITE"
ln -sf "$SITE" /etc/nginx/sites-enabled/tennis
nginx -t
systemctl enable --now nginx
systemctl reload nginx

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
	ufw allow 80/tcp && ufw allow 443/tcp
fi

certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect
echo
echo "Done: https://$DOMAIN/"
echo "Paste this address into @BotFather -> your bot -> Bot Settings -> Mini Apps -> Main App / Menu Button."
