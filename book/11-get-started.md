# 11. Get started examples

Do these in **dev**, in order. Each takes 5–15 minutes.

```bash
export IDP=https://auth-dev.grasp-daas.com
export API=https://grasp-daas.com/api
export JWT=$(curl -s -X POST "$IDP/oauth/token/" \
  -d grant_type=client_credentials -d client_id="$CLIENT_ID" -d client_secret="$CLIENT_SECRET" \
  | jq -r .access_token)
H=(-H "Authorization: Bearer $JWT" -H "Content-Type: application/json")
```

## 1. Say hello to the platform

```bash
curl -s "$IDP/auth/me/" -H "Authorization: Bearer $JWT"   # who am I
curl -s "$API/config-dev/v3/tenant/" "${H[@]}"            # my tenant
curl -s "$API/config-dev/v3/version/"                      # no auth needed
```

Decode your token: `jq -R 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | @base64d | fromjson' <<<"$JWT"`.
Find `rsc` (your tenant) and `cls`.

## 2. Connect Cursor to Commons

Follow chapter 7. Then ask Cursor:

> List what is under /config, then show me the most recent pipeline run.

You should see `ls` and `status` calls in the chat.

## 3. Store and read a file

```bash
ID=$(curl -s -X POST "$API/file-dev/v2/file/" "${H[@]}" \
  -d '{"file_path":"sandbox/hello.md","status":"active","tags":{"kind":"note"}}' | jq -r .id)
curl -s -X PUT "$API/file-dev/v2/file/$ID/content/" \
  -H "Authorization: Bearer $JWT" -H "Content-Type: text/plain" --data-binary "# Hello Commons"
curl -s "$API/file-dev/v2/file/$ID/content/" -H "Authorization: Bearer $JWT"
```

## 4. Add knowledge to the graph

```bash
curl -s -X POST "$API/knowledge-graph-dev/v1/node/" "${H[@]}" \
  -d '{"type":"person","name":"<Your Name>","status":"active","props":{"team":"<team>"}}'
curl -s -X POST "$API/knowledge-graph-dev/v1/graph/retrieve/" "${H[@]}" \
  -d '{"query":"<Your Name>"}'
```

## 5. Run a workflow with a payload

Build the three-task workflow in chapter 10, then fire it:

```bash
curl -s -X POST "$API/message-dev/v1/message/ds.workflow.pipeline.job.requested.v2/" "${H[@]}" \
  -d '{"id":"<workflow_id>","payload":{"rows":[{"id":1,"country":"NO"}]}}'
curl -s "$API/state-dev/v1/cb-job/latest/" "${H[@]}"
```

## 6. Land data in gold and query it

Follow chapter 9 with an `http` source (e.g. a public JSON API, see
`docs/examples/http.json`), then:

```bash
curl -s -X POST "$API/fetch-dev/v1/query/" "${H[@]}" \
  -d '{"sql":"SELECT count(*) FROM gold.\"<table>\""}'
```

## 7. Schedule it

```bash
SID=$(curl -s -X POST "$API/config-dev/v3/schedule/" "${H[@]}" \
  -d '{"name":"hourly","status":"active","type":"cron","cron":"0 * * * *","timezone":"Europe/Oslo"}' | jq -r .id)
curl -s -X POST "$API/config-dev/v3/map/pipeline-schedule/" "${H[@]}" \
  -d "{\"pipeline_id\":\"<pipeline_id>\",\"schedule_id\":\"$SID\"}"
```

Next hour: `GET /enqueued-job/?cb_type=pipeline` shows the queued run.

## 8. Ask the AI about your data

```bash
curl -s "$API/ai-gateway-dev/v1/openai/v1/models" "${H[@]}"   # pick an allowed model
curl -s "$API/ai-gateway-dev/v1/openai/v1/chat/completions" "${H[@]}" -d '{
  "model":"<model>",
  "messages":[{"role":"user","content":"Preview my gold datasets and plot row counts per dataset."}]}'
```

The gateway discovers tools, calls `preview`, `query` and `plot`, and returns a
link to the chart in ds-file.

## 9. Publish a playbook

Write what you learned as a playbook (chapter 8) and publish it to your tenant
first. Once it has been reviewed, the platform team promotes it to Commons.

## Done?

You have touched identity, config, files, graph, triggers, both compute paths,
the datalake, AI and MCP. Next: take the course *Build with Commons* and read
each service's OpenAPI docs at `<base>/docs/`.
