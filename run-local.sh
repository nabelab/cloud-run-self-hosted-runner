#!/usr/bin/env bash

docker build . -t actions-runner

docker run -ti --rm \
  -v "./private-key.pem:/home/runner/private-key.pem" \
  -e GITHUB_APP_ID="$GITHUB_APP_ID" \
  -e GITHUB_APP_INSTALLATION_ID="$GITHUB_APP_INSTALLATION_ID" \
  -e GITHUB_APP_PRIVATE_KEY_FILE="/home/runner/private-key.pem" \
  -e GITHUB_REPOSITORY="$GITHUB_REPOSITORY" \
  actions-runner
