# Renewal worker for ds2.kimmeloffice.com — certbot + Route53 DNS-01 plugin
# (boto3 included) plus our issue-or-renew entrypoint and nginx-reload hook.
FROM certbot/dns-route53:latest

COPY entrypoint.sh  /usr/local/bin/entrypoint.sh
COPY deploy-hook.sh /usr/local/bin/deploy-hook.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/deploy-hook.sh

# Override certbot's default entrypoint with our scheduler-friendly wrapper.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
