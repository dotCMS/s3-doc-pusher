#!/bin/bash

set -e

#########################
# Script: githubCommon.sh
# Collection of common functions used across the pipeline

# Evaluates a provided command to be echoed and then executed setting the result in a variable
#
# $1: cmd command to execute
function executeCmd {
  local cmd=${1}
  cmd=$(echo ${cmd} | tr '\n' ' \ \n')
  echo "==============
Executing cmd:
==============
${cmd}"
  eval "${cmd}"
  export cmdResult=$?
  echo "cmdResult: ${cmdResult}"
  if [[ ${cmdResult} != 0 ]]; then
    echo "Error executing: ${cmd}"
  fi
  echo
}

# Pushes to S3 an object identified by the key
#
# $1: key: key to identifies object in bucket
# $2: object: object to sore in bucket
function s3Push {
  local object=${1}
  local key=${2}
  local ct=${3}

  executeCmd "${keys_str} aws s3 cp ${object} ${bucket}/${key} --recursive ${dry_run_param}"
  # List contents in bucket for that particular key
  executeCmd "${keys_str} aws s3 ls ${bucket}/${key}"
}

dry_run=${INPUT_DRY_RUN}
[[ -z "${dry_run}" ]] && dry_run=true
[[ "${dry_run}" == 'true' ]] && dry_run_param='--dryrun'
bucket='s3://static.dotcms.com'
keys_str="export AWS_ACCESS_KEY_ID=${INPUT_AWS_ACCESS_KEY_ID}; export AWS_SECRET_ACCESS_KEY=${INPUT_AWS_SECRET_ACCESS_KEY};"

echo "##################
Github Action vars
##################
dry_run: ${dry_run}
aws_access_key_id: ${INPUT_AWS_ACCESS_KEY_ID}
aws_secret_access_key: ${INPUT_AWS_SECRET_ACCESS_KEY}
bucket: ${bucket}
"

mkdir -p /src
pushd /src
git clone https://github.com/dotCMS/documentation.git
mv documentation/* /app
popd

pushd /app
version=$(cat ./package.json \
    | grep version \
    | head -1 \
    | awk -F: '{ print $2 }' \
    | sed 's/[",]//g' \
    | tr -d '[[:space:]]')
echo "Found VERSION: ${version}"
#doc_key="docs/${version}"
doc_key="docs"

echo "Pushing documentation for ${version} version to ${bucket}"
executeCmd "yarn install --frozen-lockfile"
executeCmd "mv __staticsite_/[urlTitle].tsx pages/"
executeCmd "mv __staticsite_/codeshare/[urlTitle].tsx pages/codeshare/"
executeCmd "mv __staticsite_/codeshare/topic/[topic].tsx pages/codeshare/topic/"
executeCmd "BASE_PATH=/docs/${version} yarn build && yarn export"
popd

cp -R /app/out ./${version}

executeCmd "s3Push ./${version} ${doc_key}"
# for css in $(find ./${version} -name "*.css"); do
#   executeCmd "s3Push ${doc_key}/$(dirname ${css:2}) ${css} --guess-mime-type"
# done;
