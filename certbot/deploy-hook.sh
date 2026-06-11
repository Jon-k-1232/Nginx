#!/bin/sh
# Runs only when certbot actually issues/renews a cert. Forces a new nginx ECS
# deployment so the host-network nginx task restarts and reloads the cert from
# the shared EFS volume. nginx runs min_healthy=0 (single host, ports 443/80),
# so this is a ~few-second blip — and only happens ~6x/year on real renewals.
#
# boto3 ships in the certbot/dns-route53 base image and reads the ECS task role.
set -eu

: "${ECS_CLUSTER:?ECS_CLUSTER env required}"
: "${NGINX_SERVICE:?NGINX_SERVICE env required}"

echo "[deploy-hook] cert changed — forcing new deployment of ${NGINX_SERVICE}"
# region_name is explicit because ECS is a regional service and the container
# env may not carry AWS_REGION (Route53 above is global, so certbot itself is
# unaffected). The task def also sets AWS_REGION as a belt-and-suspenders.
python -c "import boto3, os; boto3.client('ecs', region_name=os.environ.get('AWS_REGION', 'us-west-2')).update_service(cluster=os.environ['ECS_CLUSTER'], service=os.environ['NGINX_SERVICE'], forceNewDeployment=True)"
echo "[deploy-hook] nginx redeploy triggered"
