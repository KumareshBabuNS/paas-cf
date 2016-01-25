#!/bin/bash
set -e

SCRIPT_DIR=$(cd $(dirname $0) && pwd)

env=${DEPLOY_ENV:-$1}
pipeline="create-deployer"
config="${SCRIPT_DIR}/../pipelines/create-deployer.yml"

[[ -z "${env}" ]] && echo "Must provide environment name" && exit 100

generate_vars_file() {
   set -u # Treat unset variables as an error when substituting
   cat <<EOF
---
vagrant_ip: ${VAGRANT_IP}
deploy_env: ${env}
tfstate_bucket: bucket=${env}-state
state_bucket: ${env}-state
branch_name: ${BRANCH:-master}
aws_region: ${AWS_DEFAULT_REGION:-eu-west-1}
concourse_atc_password: ${CONCOURSE_ATC_PASSWORD}
log_level: ${LOG_LEVEL:-}
EOF
}

generate_vars_file > /dev/null # Check for missing vars

bash "${SCRIPT_DIR}/deploy-pipeline.sh" \
   "${env}" "${pipeline}" "${config}" <(generate_vars_file)