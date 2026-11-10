#!/usr/bin/env bash
# Commons token for the MCP server (headersHelper) or, with --token, for your own shell.
# Usage: auth.sh [--token dev|prod]
# Credentials: COMMONS_<ENV>_CLIENT_ID / COMMONS_<ENV>_CLIENT_SECRET, else the OS keychain
# (service commons-<env>, accounts client_id and client_secret). Tokens are cached until
# two minutes before expiry in ${XDG_CACHE_HOME:-~/.cache}/commons/<env>.jwt (mode 600).
set -euo pipefail

die() { echo "commons auth: $*" >&2; exit 1; }

raw=
env=
if [[ ${1:-} == --token ]]; then
  raw=1 env=${2:-}
else
  case ${CLAUDE_CODE_MCP_SERVER_URL:-} in
    */ai-gateway-dev/*) env=dev ;;
    */ai-gateway/*) env=prod ;;
  esac
fi
case $env in
  dev) idp=https://auth-dev.grasp-daas.com ;;
  prod) idp=https://auth.grasp-daas.com ;;
  *) die "usage: auth.sh --token dev|prod" ;;
esac
command -v jq >/dev/null || die "jq is required"
command -v curl >/dev/null || die "curl is required"

stored() { # ACCOUNT
  if command -v security >/dev/null; then
    security find-generic-password -s "commons-$env" -a "$1" -w 2>/dev/null
  elif command -v secret-tool >/dev/null; then
    secret-tool lookup service "commons-$env" account "$1" 2>/dev/null
  fi
}

exp_of() {
  printf '%s' "$1" | jq -R 'split(".")[1] | gsub("-";"+") | gsub("_";"/")
    | . + ("=" * ((4 - length % 4) % 4)) | @base64d | fromjson | .exp // 0' 2>/dev/null || echo 0
}

umask 077
cache=${XDG_CACHE_HOME:-$HOME/.cache}/commons/$env.jwt
mkdir -p "${cache%/*}"
token=$(cat "$cache" 2>/dev/null || true)

if [[ -z $token ]] || (( $(exp_of "$token") < $(date +%s) + 120 )); then
  up=$(printf '%s' "$env" | tr '[:lower:]' '[:upper:]')
  id_var=COMMONS_${up}_CLIENT_ID secret_var=COMMONS_${up}_CLIENT_SECRET
  id=${!id_var:-$(stored client_id || true)}
  secret=${!secret_var:-$(stored client_secret || true)}
  [[ -n $id && -n $secret ]] || die "no credentials for $env (see the commons skill, Setup)"
  # The secret goes through stdin so it never appears in the process list.
  token=$(printf '%s' "$secret" | curl -sS --fail --max-time 8 "$idp/oauth/token/" \
    -d grant_type=client_credentials --data-urlencode "client_id=$id" \
    --data-urlencode "client_secret@-" | jq -r '.access_token // empty') || die "token request to $idp failed"
  [[ -n $token ]] || die "token response from $idp had no access_token"
  printf '%s' "$token" >"$cache"
fi

if [[ $raw ]]; then
  printf '%s\n' "$token"
else
  jq -nc --arg t "$token" '{Authorization: ("Bearer " + $t)}'
fi
