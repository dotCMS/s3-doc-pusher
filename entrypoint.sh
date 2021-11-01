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
  local key=${1}
  local object=${2}

  # Use 's3cmd' tool to push whether is a file or an entire folder
  if [[ -d ${object} ]]; then
    executeCmd "s3cmd put ${keys_str} --recursive --quiet ${object} ${bucket}/${key}"
  else
    executeCmd "s3cmd put ${keys_str} ${object} ${bucket}/${key}"
  fi

  # List contents in bucket for that particular key
  executeCmd "s3cmd ls ${keys_str} ${bucket}/${key}"
}

dry_run=${INPUT_DRY_RUN}
[[ -z "${dry_run}" ]] && dry_run=true
bucket='s3://static.dotcms.com'
keys_str="--access_key=${INPUT_AWS_ACCESS_KEY_ID} --secret_key=${INPUT_AWS_SECRET_ACCESS_KEY}"

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

[[ "${dry_run}" == 'true' ]] && doc_key="cicd-test/${doc_key}"
executeCmd "s3Push ${doc_key}/ ./${version}"
executeCmd "s3cmd ls ${keys_str} ${bucket}/${doc_key}/${version}"
executeCmd "s3cmd ls ${keys_str} ${bucket}/${doc_key}/${version}/"
