#!/usr/bin/env bash
# Setup ACME-friendly nginx hints + weekly Let's Encrypt safety renew (ISPmanager).
# Run ON the VPS as root.
#
# Usage:
#   DOMAIN=example.com CERT_ID=1 bash setup-ssl-autorenew.sh
#   DOMAIN=example.com CERT_ID=1 CERT_BASENAME=example.com_le1 CHECK_URL=https://example.com/health bash setup-ssl-autorenew.sh
#   DOMAIN=example.com CERT_ID=1 RENEW_NOW=1 bash setup-ssl-autorenew.sh
#
# Optional:
#   NGINX_VHOST=/etc/nginx/vhosts/www-root/example.com.conf
#   LISTEN_IP=1.2.3.4          # for curl --resolve smoke tests
#   DAYS_BEFORE=30
#   SKIP_NGINX_PATCH=1         # only install renew script + cron
#
set -euo pipefail

DOMAIN="${DOMAIN:?Set DOMAIN=your.domain}"
CERT_ID="${CERT_ID:?Set CERT_ID=N (from mgrctl -m ispmgr sslcert / LE logs)}"
CERT_BASENAME="${CERT_BASENAME:-${DOMAIN}_le1}"
CRT="/var/www/httpd-cert/www-root/${CERT_BASENAME}.crt"
LE_WEBROOT="/usr/local/mgr5/www/letsencrypt"
DAYS_BEFORE="${DAYS_BEFORE:-30}"
RENEW_NOW="${RENEW_NOW:-0}"
SKIP_NGINX_PATCH="${SKIP_NGINX_PATCH:-0}"
CHECK_URL="${CHECK_URL:-}"
LISTEN_IP="${LISTEN_IP:-}"
NGINX_VHOST="${NGINX_VHOST:-/etc/nginx/vhosts/www-root/${DOMAIN}.conf}"

SLUG="$(echo "$DOMAIN" | tr '.:' '--' | tr -cd 'a-zA-Z0-9-_')"
RENEW_SH="/usr/local/sbin/renew-${SLUG}-le.sh"

if [[ ! -x /usr/local/mgr5/sbin/letsencrypt ]]; then
  echo "ERROR: /usr/local/mgr5/sbin/letsencrypt not found (ISPmanager LE required)" >&2
  exit 1
fi

if [[ ! -f "$CRT" ]]; then
  echo "WARN: cert file missing: $CRT (issue LE in ISPmanager first)" >&2
fi

install_renew_script() {
  cat > "$RENEW_SH" <<EOF
#!/bin/bash
set -euo pipefail
CRT="$CRT"
CERT_ID="$CERT_ID"
DAYS_BEFORE="$DAYS_BEFORE"
end=\$(openssl x509 -in "\$CRT" -noout -enddate | cut -d= -f2)
end_ts=\$(date -d "\$end" +%s)
now_ts=\$(date +%s)
days=\$(( (end_ts - now_ts) / 86400 ))
logger -t renew-${SLUG}-le "cert days left=\$days domain=$DOMAIN"
if [ "\$days" -lt "\$DAYS_BEFORE" ]; then
  /usr/local/mgr5/sbin/letsencrypt --cert-id "\$CERT_ID"
  nginx -t && nginx -s reload
  logger -t renew-${SLUG}-le "renewed ok domain=$DOMAIN"
fi
EOF
  chmod 755 "$RENEW_SH"
  echo "Installed $RENEW_SH"
}

install_cron() {
  local tmp
  tmp="$(mktemp)"
  crontab -l 2>/dev/null | grep -v "renew-${SLUG}-le" > "$tmp" || true
  echo "15 4 * * 1	${RENEW_SH} >/dev/null 2>&1" >> "$tmp"
  crontab "$tmp"
  rm -f "$tmp"
  echo "Cron: weekly Mon 04:15 -> $RENEW_SH"
}

patch_nginx_acme() {
  if [[ ! -f "$NGINX_VHOST" ]]; then
    echo "WARN: nginx vhost not found: $NGINX_VHOST — skip nginx patch; add ACME location manually" >&2
    return 0
  fi
  cp -a "$NGINX_VHOST" "${NGINX_VHOST}.bak.ssl.$(date +%Y%m%d%H%M%S)"

  python3 - "$NGINX_VHOST" "$DOMAIN" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
domain = sys.argv[2]
text = path.read_text()
marker = "ACME must win over location / redirect (HTTP-01)"
acme = f"""
    # {marker}
    location ^~ /.well-known/acme-challenge/ {{
        default_type text/plain;
        alias /usr/local/mgr5/www/letsencrypt/;
    }}
"""

# 1) Remove server-level return 301 once (HTTP block) and ensure location / redirects
old_return = "    return 301 https://$host$request_uri;\n"
if old_return in text:
    text = text.replace(old_return, "", 1)
    # insert redirect into first location / before listen :80
    idx80 = text.find(":80;")
    if idx80 > 0:
        http = text[:idx80]
        loc = http.find("\tlocation / {")
        marker_loc = "\tlocation / {"
        if loc < 0:
            loc = http.find("location / {")
            marker_loc = "location / {"
        if loc >= 0 and "return 301 https://" not in text[loc:idx80]:
            insert_at = loc + len(marker_loc)
            text = text[:insert_at] + "\n\t\treturn 301 https://$host$request_uri;" + text[insert_at:]
    print("Moved HTTP return 301 into location /")

# 2) Insert ACME into HTTP (before first listen :80) and HTTPS (before listen :443) if missing
def insert_before_listen(src: str, listen_needle: str, block: str) -> str:
    idx = src.find(listen_needle)
    if idx < 0:
        return src
    head = src[:idx]
    if marker in head[head.rfind("server {"):]:
        return src
    # after last error_log before this listen, else before listen
    err = "error_log "
    pos = head.rfind(err)
    if pos < 0:
        insert_at = idx
    else:
        insert_at = head.find("\n", pos) + 1
    return src[:insert_at] + block + "\n" + src[insert_at:]

text = insert_before_listen(text, ":80;", acme)
text = insert_before_listen(text, ":443", acme)

# 3) Prefer explicit includes without duplicate letsencrypt.conf if ACME inlined
glob_inc = "\tinclude /etc/nginx/vhosts-includes/*.conf;\n"
explicit = (
    "\tinclude /etc/nginx/vhosts-includes/awstats-nginx.conf;\n"
    "\tinclude /etc/nginx/vhosts-includes/blacklist-nginx.conf;\n"
    "\tinclude /etc/nginx/vhosts-includes/disabled.conf;\n"
    "\tinclude /etc/nginx/vhosts-includes/phpmyadmin-nginx.conf;\n"
    "\tinclude /etc/nginx/vhosts-includes/roundcube-nginx.conf;\n"
    "\t# letsencrypt.conf skipped: ACME location inlined (setup-ssl-autorenew.sh)\n"
)
if glob_inc in text and marker in text:
    text = text.replace(glob_inc, explicit)
    print("Replaced vhosts-includes/*.conf to avoid duplicate ACME location")

path.write_text(text)
print(f"Patched {path}")
PY

  if nginx -t; then
    nginx -s reload
    echo "nginx reloaded"
  else
    echo "ERROR: nginx -t failed — restore from ${NGINX_VHOST}.bak.ssl.*" >&2
    exit 1
  fi
}

warn_nested_proxy() {
  if [[ ! -f "$NGINX_VHOST" ]]; then
    return 0
  fi
  if grep -q "proxy_pass http://127.0.0.1:" "$NGINX_VHOST" \
    && grep -q "try_files /does_not_exists @fallback" "$NGINX_VHOST"; then
    echo "WARN: vhost may nest try_files @fallback inside Node proxy_pass — API can 404 via Apache." >&2
    echo "      See .cursor/rules/ssl-letsencrypt-vps.mdc — clean location / { proxy_pass Node; }" >&2
  fi
}

smoke_acme() {
  mkdir -p "$LE_WEBROOT"
  echo "acme-ok" > "$LE_WEBROOT/setup-ssl-probe"
  chmod 644 "$LE_WEBROOT/setup-ssl-probe"
  local resolve=()
  if [[ -n "$LISTEN_IP" ]]; then
    resolve=(--resolve "${DOMAIN}:80:${LISTEN_IP}" --resolve "${DOMAIN}:443:${LISTEN_IP}")
  fi
  echo "=== HTTP ACME (want 200) ==="
  curl -sI "${resolve[@]}" "http://${DOMAIN}/.well-known/acme-challenge/setup-ssl-probe" | head -8 || true
  echo "body: $(curl -s "${resolve[@]}" "http://${DOMAIN}/.well-known/acme-challenge/setup-ssl-probe" || true)"
  rm -f "$LE_WEBROOT/setup-ssl-probe"
}

echo "DOMAIN=$DOMAIN CERT_ID=$CERT_ID CRT=$CRT"
install_renew_script
install_cron

if [[ "$SKIP_NGINX_PATCH" != "1" ]]; then
  patch_nginx_acme
  warn_nested_proxy
fi

if [[ "$RENEW_NOW" == "1" ]]; then
  /usr/local/mgr5/sbin/letsencrypt --cert-id "$CERT_ID"
  nginx -t && nginx -s reload
  echo "Renewed now"
fi

if [[ -f "$CRT" ]]; then
  echo "=== cert dates ==="
  openssl x509 -in "$CRT" -noout -dates -subject
fi

smoke_acme

if [[ -n "$CHECK_URL" ]]; then
  echo "=== check URL ==="
  curl -sSI "$CHECK_URL" | head -8 || true
fi

echo "DONE. ISPmanager daily LE + weekly safety renew for $DOMAIN"
