#!/usr/bin/env bash

set -e

if [[ ! -x "$(command -v kubectl)" ]]; then
    echo "kubectl (https://kubernetes.io/docs/tasks/tools/install-kubectl/) not found"
    exit 1
fi

if [[ ! -x "$(command -v helm)" ]]; then
    echo "helm (https://helm.sh/docs/using_helm/#installing-helm) not found"
    exit 1
fi

if [[ ! -x "$(command -v hub)" ]]; then
    echo "hub (https://github.com/github/hub#installation) not found"
    exit 1
fi

if [[ ! -x "$(command -v jq)" ]]; then
    echo "jq (https://stedolan.github.io/jq/download/) not found"
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
GITHUB_USER=${1:-jwenz723}
REPO_NAME=flux-grpcdemo
REPO_URL=git@github.com:${GITHUB_USER}/${REPO_NAME}
REPO_BRANCH=master
GIT_PATH=${2:-staging}
TEMP=${REPO_ROOT}/temp

echo "GITHUB_USER: $GITHUB_USER"
echo "GIT_PATH: $GIT_PATH"

rm -rf ${TEMP} && mkdir ${TEMP}

cat <<EOF >> ${TEMP}/flux-values.yaml
helmOperator:
  create: true
  createCRD: true
  configureRepositories:
    enable: true
    volumeName: repositories-yaml
    secretName: flux-helm-repositories
    cacheVolumeName: repositories-cache
    repositories:
      - caFile: ""
        cache: stable-index.yaml
        certFile: ""
        keyFile: ""
        name: stable
        password: ""
        url: https://kubernetes-charts.storage.googleapis.com
        username: ""
EOF

helm repo add fluxcd https://fluxcd.github.io/flux

echo ">>> Installing Flux for ${REPO_URL}"
helm upgrade -i flux --wait \
--set git.url=${REPO_URL} \
--set git.branch=${REPO_BRANCH} \
--set git.pollInterval=15s \
--set git.path=${GIT_PATH} \
--set helmOperator.chartsSyncInterval=15s \
--set registry.pollInterval=15s \
--set additionalArgs={"--manifest-generation=true"} \
--namespace flux \
-f ${TEMP}/flux-values.yaml \
fluxcd/flux

kubectl -n flux rollout status deployment/flux

# Create a deploy key
publicKey=$(fluxctl identity --k8s-fwd-ns flux)
echo "public deploy key generated by flux: ${publicKey}"

echo "creating deploy key"
hub api -X POST /repos/${GITHUB_USER}/${REPO_NAME}/keys -F title=flux-grpcdemo -F key="${publicKey}"