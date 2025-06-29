#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

echo "GITHUB_REPOSITORY=$GITHUB_REPOSITORY" >&2
echo "GITHUB_APP_ID=$GITHUB_APP_ID" >&2
echo "GITHUB_APP_INSTALLATION_ID=$GITHUB_APP_INSTALLATION_ID" >&2
echo "GITHUB_APP_PRIVATE_KEY_FILE=${GITHUB_APP_PRIVATE_KEY_FILE:-}" >&2
echo "GITHUB_APP_PRIVATE_KEY_SECRET_ID=${GITHUB_APP_PRIVATE_KEY_SECRET_ID:-}" >&2
echo "GITHUB_APP_PRIVATE_KEY_SECRET_VERSION=${GITHUB_APP_PRIVATE_KEY_SECRET_VERSION:-latest}" >&2

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

get_metadata() {
  curl -s \
    -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/$1"
}

print_private_key() {
  if [[ -n "${GITHUB_APP_PRIVATE_KEY_FILE:-}" ]]; then
    cat "$GITHUB_APP_PRIVATE_KEY_FILE"
    return
  fi

  local project_id access_token url

  project_id="$(get_metadata "project/project-id")"
  access_token="$(get_metadata "instance/service-accounts/default/token" | jq -r '.access_token')"

  url="https://secretmanager.googleapis.com/v1/projects/${project_id}/secrets/${GITHUB_APP_PRIVATE_KEY_SECRET_ID}/versions/${GITHUB_APP_PRIVATE_KEY_SECRET_VERSION}:access"
  curl -sf -H "Authorization: Bearer ${access_token}" "$url" | jq -r '.payload.data' | tr '_-' '/+' | base64 -d
}

get_registration_token() {
  local private_key now iat exp header payload unsigned signature jwt access_token

  private_key=$(mktemp)
  print_private_key >"$private_key"
  trap 'rm -f "$private_key"' RETURN

  now=$(date +%s)
  iat=$((now))
  exp=$((now + 60))

  header='{"alg":"RS256","typ":"JWT"}'
  payload=$(printf '{"iat":%d,"exp":%d,"iss":%d}' "$iat" "$exp" "$GITHUB_APP_ID")
  unsigned="$(printf %s "$header" | b64url).$(printf %s "$payload" | b64url)"
  signature="$(printf %s "$unsigned" | openssl dgst -sha256 -sign "$private_key" -binary | b64url)"
  jwt="$unsigned.$signature"

  access_token=$(curl -fsSL -X POST \
    -H "Authorization: Bearer $jwt" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/app/installations/${GITHUB_APP_INSTALLATION_ID}/access_tokens" |
    jq -r .token)

  curl -fsSL -X POST \
    -H "Authorization: Bearer $access_token" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/runners/registration-token" |
    jq -r .token
}

token=$(get_registration_token)

./config.sh \
  --unattended \
  --url "https://github.com/${GITHUB_REPOSITORY}" \
  --token "$token" \
  --name "${CLOUD_RUN_REVISION}-$(get_metadata instance/id | head -c32)" \
  --labels "cloudrun,linux" \
  --work _work \
  --replace \
  --disableupdate \
  --ephemeral

unset GITHUB_APP_ID
unset GITHUB_APP_INSTALLATION_ID
unset GITHUB_APP_PRIVATE_KEY_FILE
unset GITHUB_REPOSITORY

exec ./run.sh
