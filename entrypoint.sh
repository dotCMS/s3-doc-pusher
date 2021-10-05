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

: ${DRY_RUN:=true} && export DRY_RUN
bucket='s3://static.dotcms.com'
keys_str="--access_key=${aws_access_key_id} --secret_key=${aws_secret_access_key}"

echo "##################
Github Action vars
##################
DRY_RUN: ${DRY_RUN}
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
doc_key="docs/${version}"

echo "Pushing documentation for ${version} version to ${bucket}"
executeCmd "yarn install --frozen-lockfile"
executeCmd "mv __staticsite_/[urlTitle].tsx pages/"
executeCmd "mv __staticsite_/codeshare/[urlTitle].tsx pages/codeshare/"
executeCmd "mv __staticsite_/codeshare/topic/[topic].tsx pages/codeshare/topic/"
executeCmd "BASE_PATH=/${version} yarn build && yarn export"
popd

cp -R /app/out ./${version}

if [[ "${DRY_RUN}" != 'true' ]]; then
  s3Push ${doc_key}/ ./${version}
else
  echo "Since DRY_RUN is true, skipping push of ${version} version to S3 bucket ${bucket}"
  echo "Command to run when not in DRY_RUN mode:
  s3Push ${doc_key}/ ./${version} -> 
  s3cmd put ${keys_str} --recursive --quiet ${object} ${bucket}/${key}
"
fi
