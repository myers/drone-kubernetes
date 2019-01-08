#!/bin/bash

set -euo pipefail

export KUBECONFIG=/tmp/kubeconfig

if [ -z "${PLUGIN_KUBERNETES_TOKEN:-}" ]; then
  echo "ERROR: You must set 'kubernetes_token'"
  exit 1
fi

if [ -z "${PLUGIN_TAG:-}" ]; then
  echo "ERROR: You must set 'tag'"
  exit 1
fi

if [ -z "${PLUGIN_REPO:-}" ]; then
  echo "ERROR: You must set 'repo'"
  exit 1
fi

if [ -z "${PLUGIN_KUBERNETES_SERVER:-}" ]; then
  echo "ERROR: You must set 'kubernetes_server'"
  exit 1
fi

if [ -z "${PLUGIN_DEPLOYMENT:-}" ]; then
  echo "ERROR: You must set 'deployment'"
  exit 1
fi

if [ -z "${PLUGIN_CONTAINER:-}" ]; then
  echo "ERROR: You must set 'container'"
  exit 1
fi

if [ -z "${PLUGIN_NAMESPACE:-}" ]; then
  PLUGIN_NAMESPACE="default"
fi

if [ -z "${PLUGIN_KUBERNETES_USER:-}" ]; then
  PLUGIN_KUBERNETES_USER="default"
fi

kubectl config set-credentials default --token=${PLUGIN_KUBERNETES_TOKEN}
if [ -z "${PLUGIN_KUBERNETES_CERT:-}" ]; then
  echo "WARNING: Using insecure connection to cluster"
  kubectl config set-cluster default --server=${PLUGIN_KUBERNETES_SERVER} --insecure-skip-tls-verify=true
else
  echo "${PLUGIN_KUBERNETES_CERT}" | base64 -d > ca.crt
  kubectl config set-cluster default --server=${PLUGIN_KUBERNETES_SERVER} --certificate-authority=ca.crt
fi

kubectl config set-context default --cluster=default --user=${PLUGIN_KUBERNETES_USER}
kubectl config use-context default

IFS=',' read -r -a DEPLOYMENTS <<< "${PLUGIN_DEPLOYMENT:-}"
IFS=',' read -r -a CONTAINERS <<< "${PLUGIN_CONTAINER:-}"
for DEPLOY in ${DEPLOYMENTS[@]}; do
  echo Deploying to $PLUGIN_KUBERNETES_SERVER
  for CONTAINER in ${CONTAINERS[@]}; do
    if [ ${PLUGIN_FORCE:-} == "true" ]; then
      # force changing the image by changing it to the TAG + FORCE then changing it back
      kubectl -n ${PLUGIN_NAMESPACE} set image deployment/${DEPLOY} \
        ${CONTAINER}=${PLUGIN_REPO}:${PLUGIN_TAG:-}FORCE
    fi
    kubectl -n ${PLUGIN_NAMESPACE} set image deployment/${DEPLOY} \
      ${CONTAINER}=${PLUGIN_REPO}:${PLUGIN_TAG:-} --record
  done
done
