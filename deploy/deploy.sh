#!/usr/bin/env bash
# Puts the game on a Debian/Ubuntu server behind nginx with a free HTTPS certificate
# (Telegram Mini Apps need HTTPS). Run from the unpacked archive:
#
#   sudo ./deploy.sh                      # no domain: uses <ip>.sslip.io
#   sudo ./deploy.sh tennis.example.com   # your own domain (A record -> this server)
#   sudo ./deploy.sh --update             # only replace the game files (new version)
#
# Safe for a server that already runs other things: it adds one nginx site and stops
# if ports 80/443 belong to something other than nginx.
set -euo pipefail
cd "$(dirname "$0")"
WEB_DIR=/var/www/tennis

if [ "${1:-}" = "--update" ]; then
	mkdir -p "$WEB_DIR"
	cp -r web/. "$WEB_DIR/"
	echo "Updated files in $WEB_DIR"
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
sed "s/__DOMAIN__/$DOMAIN/g" nginx-tennis.conf > /etc/nginx/sites-available/tennis
ln -sf /etc/nginx/sites-available/tennis /etc/nginx/sites-enabled/tennis
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
