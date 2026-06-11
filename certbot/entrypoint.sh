#!/bin/sh
# Certbot renewal entrypoint for ds2.kimmeloffice.com.
#
# Runs as a scheduled ECS task (EventBridge twice daily). On the FIRST run it
# issues the cert via Let's Encrypt DNS-01 (Route 53); on every subsequent run
# `certbot renew` is a no-op until the cert is within 30 days of expiry, then
# it renews and the deploy-hook rolls nginx so it picks up the new cert.
#
# DNS-01 is the only viable challenge: ds2.kimmeloffice.com resolves to a
# private VPC IP (internal app), so HTTP-01 could never reach it. AWS creds
# come from the ECS task role (boto3 reads the task credential endpoint).
set -eu

DOMAIN="${CERT_DOMAIN:-ds2.kimmeloffice.com}"
EMAIL="${CERTBOT_EMAIL:-admin@jimkimmel.com}"

echo "[certbot] $(date -u +%FT%TZ) starting for ${DOMAIN}"

if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
   echo "[certbot] no existing cert — issuing via DNS-01 (Route 53)"
   certbot certonly \
      --dns-route53 \
      --non-interactive --agree-tos \
      -m "${EMAIL}" \
      -d "${DOMAIN}" \
      --key-type ecdsa \
      --preferred-challenges dns-01
   # First issuance: roll nginx so it serves the EFS cert (it may have started
   # before the cert existed, or this is the very first cutover).
   /usr/local/bin/deploy-hook.sh
else
   echo "[certbot] cert present — renewing if within 30 days of expiry"
   certbot renew \
      --dns-route53 \
      --non-interactive \
      --deploy-hook /usr/local/bin/deploy-hook.sh
fi

echo "[certbot] $(date -u +%FT%TZ) done"
