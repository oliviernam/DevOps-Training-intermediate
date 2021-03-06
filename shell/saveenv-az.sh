#!/bin/bash
echo "\
export APP_NAME=${APP_NAME}
export APP_REGISTRY=${APP_REGISTRY}
export CLUSTER_NAME=${CLUSTER_NAME}
export DSSC_NAMESPACE=${DSSC_NAMESPACE}
export DSSC_USERNAME=${DSSC_USERNAME}
export DSSC_PASSWORD=${DSSC_PASSWORD}
export DSSC_REGUSER=${DSSC_REGUSER}
export DSSC_REGPASSWORD=${DSSC_REGPASSWORD}
export DSSC_AC=${DSSC_AC}
export DSSC_HOST_IP=${DSSC_HOST_IP}
export DSSC_HOST=${DSSC_HOST}
export TREND_AP_KEY=${TREND_AP_KEY}
export TREND_AP_SECRET=${TREND_AP_SECRET}
export AZURE_DEVOPS_EXT_PAT=${AZURE_DEVOPS_EXT_PAT}
export DEVOPS_ORGANIZATION=${DEVOPS_ORGANIZATION}
export GITHUB_USERNAME=${GITHUB_USERNAME}
" > ~/.az-lab.sh