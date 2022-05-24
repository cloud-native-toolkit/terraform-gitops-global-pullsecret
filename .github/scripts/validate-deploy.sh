#!/usr/bin/env bash

GIT_REPO=$(cat git_repo)
GIT_TOKEN=$(cat git_token)

BIN_DIR=$(cat .bin_dir)

export PATH="${BIN_DIR}:${PATH}"

if ! command -v oc 1> /dev/null 2> /dev/null; then
  echo "oc cli not found" >&2
  exit 1
fi

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli not found" >&2
  exit 1
fi

export KUBECONFIG=$(cat .kubeconfig)
NAMESPACE=$(cat .namespace)
COMPONENT_NAME=$(jq -r '.name // "my-module"' gitops-output.json)
BRANCH=$(jq -r '.branch // "main"' gitops-output.json)
SERVER_NAME=$(jq -r '.server_name // "default"' gitops-output.json)
LAYER=$(jq -r '.layer_dir // "2-services"' gitops-output.json)
TYPE=$(jq -r '.type // "base"' gitops-output.json)

mkdir -p .testrepo

git clone https://${GIT_TOKEN}@${GIT_REPO} .testrepo

cd .testrepo || exit 1

find . -name "*"

if [[ ! -f "argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml" ]]; then
  echo "ArgoCD config missing - argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml"
  exit 1
fi

echo "Printing argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml"
cat "argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml"

if [[ ! -f "payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml" ]]; then
  echo "Application values not found - payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml"
  exit 1
fi

echo "Printing payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml"
cat "payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml"

count=0
until kubectl get namespace "${NAMESPACE}" 1> /dev/null 2> /dev/null || [[ $count -eq 20 ]]; do
  echo "Waiting for namespace: ${NAMESPACE}"
  count=$((count + 1))
  sleep 15
done

if [[ $count -eq 20 ]]; then
  echo "Timed out waiting for namespace: ${NAMESPACE}"
  exit 1
else
  echo "Found namespace: ${NAMESPACE}. Sleeping for 60 seconds to wait for everything to settle down"
  sleep 60
fi

GLOBAL_SECRET="pull-secret"
OPENSHIFT_NAMESPACE="openshift-config"
count=0
until kubectl get secret "${GLOBAL_SECRET}" -n "${OPENSHIFT_NAMESPACE}" || [[ $count -eq 20 ]]; do
  echo "Waiting for secret/${GLOBAL_SECRET} in ${OPENSHIFT_NAMESPACE}"
  count=$((count + 1))
  sleep 15
done

if [[ $count -eq 20 ]]; then
  echo "Timed out waiting for deployment/${GLOBAL_SECRET} in ${OPENSHIFT_NAMESPACE}"
  kubectl get secret -n "${OPENSHIFT_NAMESPACE}"
  exit 1
fi

count=0
until kubectl get job "global-pull-secret-append" -n "${NAMESPACE}" || [[ $count -eq 20 ]]; do
  echo "Waiting for job/global-pull-secret-append in ${NAMESPACE}"
  count=$((count + 1))
  sleep 15
done

if [[ $count -eq 20 ]]; then
  echo "Timed out waiting for job/global-pull-secret-append in ${NAMESPACE}"
  kubectl get job "global-pull-secret-append" -n "${NAMESPACE}"
  exit 1
fi

oc wait --for=condition=complete job/global-pull-secret-append -n "${NAMESPACE}" --timeout=120s

oc get secret/${GLOBAL_SECRET} \
      -n ${OPENSHIFT_NAMESPACE} \
      --template='{{index .data ".dockerconfigjson" | base64decode}}' > ./global_pull_secret.cfg

echo "Pull secret:"
cat ./global_pull_secret.cfg

if ! grep -Fxq "test-server" global_pull_secret.cfg; then
  echo "test-server key was not found"
  exit 1
fi


cd ..
rm -rf .testrepo
