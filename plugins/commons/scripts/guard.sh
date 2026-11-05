#!/usr/bin/env bash
# PreToolUse guard: keeps Commons credentials and tenant data out of Claude's context and
# puts the user in front of every change. A heuristic, not a boundary: IAM and the tenant
# AI profile are the boundary (see the commons-safety skill).
set -uo pipefail

command -v jq >/dev/null || {
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"commons: install jq; the guard needs it"}}'
  exit 0
}
reply() { # DECISION REASON
  jq -nc --arg d "$1" --arg r "commons: $2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}
# Fail closed: a crash must not let the call through.
trap 'code=$?; (( code == 0 )) || reply deny "guard failed (exit $code); denied."' EXIT

input=$(cat)
name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
[[ -n $name ]] || reply deny "unreadable hook input; denied."
arg() {
  printf '%s' "$input" | jq -r --arg k "$1" '.tool_input[$k] | if . == null then empty elif type == "string" then . else tojson end'
}

case $name in
  Bash | Read | Grep | Glob)
    text="$(arg command) $(arg file_path) $(arg path) $(arg pattern)"
    printf '%s' "$text" | grep -qE '\.cache/|XDG_CACHE_HOME|\.jwt|scripts/auth\.sh|commons-(dev|prod)|CLIENT_SECRET|find-generic-password|secret-tool' &&
      reply deny "Commons credentials and tokens stay out of the conversation. Ask the user to run this in their own terminal."
    exit 0 ;;
  mcp__*commons*__*) tool=${name##*__} ;;
  *) exit 0 ;;
esac

mode=${CLAUDE_PLUGIN_OPTION_DATA_ACCESS:-aggregates}
[[ $mode == aggregates || $mode == rows ]] || mode=metadata
case ${CLAUDE_PLUGIN_OPTION_MCP_URL:-} in */ai-gateway-dev/*) env=dev ;; *) env=PROD ;; esac
path=$(arg path)
[[ -z $path ]] || path=/${path#/}

content() { # REASON — document or state content entering the context
  case $mode in
    metadata) reply deny "data_access=metadata blocks $1. Work from metadata (ls, info, schema) or ask the user to raise data_access." ;;
    aggregates) reply ask "$1 enters Claude's context. Approve only if needed." ;;
  esac
  exit 0
}

case $tool in
  write | rm | run)
    [[ $tool == write && $path == /vault* ]] &&
      reply deny "secret values must never pass through Claude. The user creates or rotates secrets from their own terminal or the Commons UI."
    [[ $path == /iam* ]] && reply ask "$env: $tool $path changes permissions. Check it is least privilege."
    reply ask "$env: $tool $path changes tenant state." ;;
  frames) reply ask "$env: frames stores new image files in ds-file." ;;
  generate_image) reply ask "$env: the prompt is sent to an external image model and the result stored in ds-file. Keep tenant data out of the prompt." ;;
  websearch) reply ask "the query leaves the platform for a public search provider. Keep tenant data out of it." ;;
  preview)
    [[ $mode == rows || $(arg rows) == 0 ]] || reply deny "data_access=$mode: call preview with rows: 0 (schema and counts only)." ;;
  query)
    [[ $mode == metadata ]] && reply deny "data_access=metadata blocks SQL results. Use preview with rows: 0, schema or text_to_sql."
    if [[ $mode == aggregates ]]; then
      sql=$(arg sql | tr '[:upper:]\n' '[:lower:] ' | sed -E 's#/\*([^*]|\*+[^*/])*\*+/##g; s/--.*$//')
      printf ' %s' "$sql" | grep -qE '[[:space:])]over[[:space:]]*\(' &&
        reply deny "data_access=aggregates: window functions return rows. Use GROUP BY."
      printf '%s' "$sql" | grep -qE '(count|sum|avg|min|max|median|stddev|approx_count_distinct)[[:space:]]*\(|group[[:space:]]+by' ||
        reply deny "data_access=aggregates: return aggregates (COUNT, SUM, AVG, GROUP BY), not rows. Ask the user to switch data_access to rows if rows are required."
    fi
    max=$(arg max_rows)
    [[ ${max:-100} =~ ^[0-9]+$ ]] || reply deny "max_rows must be a whole number."
    (( ${max:-100} <= 100 )) || reply ask "query returns up to $max rows into Claude's context." ;;
  plot)
    [[ $mode == metadata && -n $(arg sql) ]] && reply deny "data_access=metadata blocks SQL results." ;;
  cat | info)
    [[ $path =~ ^/files/[^/]+/content || $path =~ ^/state/[0-9a-fA-F-]{36} ]] && content "the content of $path" ;;
  extract | transcribe | inspect) content "the content of $path" ;;
  grep)
    [[ $mode != metadata || $(arg snippets) == false ]] || reply deny "data_access=metadata: call grep with snippets: false." ;;
esac
exit 0
