#!/bin/bash

set -e

echo $PWD
ls

# Ensure the jobfile exists
if [[ ! -f "${INPUT_FILENAME}" ]]; then
    printf "${INPUT_FILENAME} does not exist.\n"
    exit 1
fi

# Wget the comparison file
PARENT_SHA=$(git log --pretty=%P -n 1 ${CURRENT_SHA} | cut -d ' ' -f 1)
JOBFILE="https://raw.githubusercontent.com/${INPUT_REPO}/${PARENT_SHA}/${INPUT_FILENAME}"
TMP=$(mktemp -d)

BASENAME=$(basename ${INPUT_FILENAME})
wget ${JOBFILE} -O "${TMP}/${BASENAME}"
if [[ "$?" != "0" ]]; then
    printf "Issue getting previous job file ${JOBFILE}\n"
    exit 1
fi

JOBFILE="${TMP}/${BASENAME}"
if [[ ! -f "${JOBFILE}" ]]; then
    printf "${JOBFILE} does not exist.\n"
    exit 1
fi

# If we are verbatim given a previous filename, use it
if [ ! -z ${INPUT_PREVIOUS_FILENAME} ]; then 
    JOBFILE="${INPUT_PREVIOUS_FILENAME}"
fi

# Required to have slack webhook in environment
if [ -z ${SLACK_WEBHOOK+x} ]; then
    printf "Warning, SLACK_WEBHOOK not found, will not deploy to slack.\n"
fi

# Are we deploying?
DEPLOY=true
if [[ "${INPUT_DEPLOY}" == "false" ]]; then
    DEPLOY=false
fi

# Do not deploy ever on test
if [[ "${INPUT_TEST}" == "true" ]]; then
    printf "🚧️ This is a test run! Deploy set to false 🚧️\n"
    DEPLOY=false
fi

# If everything not unset and deploy twitter is true, we deploy!
DEPLOY_TWITTER=false
if [ ! -z ${TWITTER_API_KEY+x} ] && [ ! -z ${TWITTER_API_SECRET+x} ] && [ ! -z ${TWITTER_CONSUMER_KEY+x} ] && [ ! -z ${TWITTER_CONSUMER_SECRET+x} ] && [[ "${TWITTER_DEPLOY}" == "true" ]]; then
    DEPLOY_TWITTER=true
fi

# likewise for mastodon
DEPLOY_MASTODON=false
if [ ! -z ${MASTODON_ACCESS_TOKEN+x} ] && [ ! -z ${MASTODON_API_BASE_URL+x} ] && [[ "${MASTODON_DEPLOY}" == "true" ]]; then
    DEPLOY_MASTODON=true
fi

COMMAND="python ${ACTION_DIR}/find-updates.py update --keys ${INPUT_KEYS} --unique ${INPUT_UNIQUE} --original ${JOBFILE} --updated ${INPUT_FILENAME}"

if [[ "${DEPLOY}" == "true" ]]; then
  COMMAND="${COMMAND} --deploy"
fi

if [[ "${INPUT_TEST}" == "true" ]]; then
  COMMAND="${COMMAND} --test"
fi

if [[ "${DEPLOY_TWITTER}" == "true" ]]; then
  COMMAND="${COMMAND} --deploy-twitter"
fi

if [[ "${DEPLOY_MASTODON}" == "true" ]]; then
  COMMAND="${COMMAND} --deploy-mastodon"
fi

echo "${COMMAND}"

${COMMAND}
echo $?
