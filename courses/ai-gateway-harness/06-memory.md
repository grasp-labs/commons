---
title: Memory
---
# Lesson 5 — Memory

The gateway is stateless about chat history: the client resends the
conversation every time. Yet the harness remembers a lot. This lesson explains
the four kinds of memory, why each lives where it does, and how prompt caching
makes long conversations affordable.

## Four memories, four stores

| Memory | Question it answers | Where | Lives for |
|---|---|---|---|
| Session state | "What is loaded right now?" | Valkey (Redis) | until the session goes idle |
| The ledger | "What was called, and did it work?" | Postgres `llm_trajectory_event` | 90 days |
| Session summaries | "What did I do last week?" | Postgres `llm_session_summary` | no fixed expiry; erased with the user |
| Saved facts | "What should you always know about me?" | Postgres `llm_user_memory` | until forgotten; erased with the user |

Mixing these up is a design error. They have different speeds, lifetimes and
owners.

## 1. Session state (Valkey)

The working set (lesson 3) and the single-use expand tokens. Every operation is
one fast atomic call. Tokens use Redis's own expiry and are consumed with
`GETDEL`, so a token can never be used twice, even across replicas. Nothing needs
cleaning up: abandoned sessions simply expire.

When Valkey is not configured (local development), an in-memory store with the
same rules is used. One shared test runs against both, so they cannot drift
apart.

## 2. The ledger

Every real tool call writes events:

```
invoke    tool=mcp_tripletex__search_invoices  session=5f0c...  turn=9e8d...  user=kari...
success   duration_ms=840  tokens_in=35  tokens_out=1200
```

A skill writes an `invoke` and an outcome for the skill as a whole. Later,
classification adds `user_kept`, `user_redid` or `loop_detected`, and a rating
adds `user_approved` or `user_rejected` (lesson 6).

**Every event carries `user_sub`** (Kari's email from the JWT). It serves three
purposes:

1. A rating is accepted only from the user whose run it was.
2. Auto-capture requires a pattern from at least two different users.
3. When Kari is deleted, her `user_sub` is set to `NULL`, so stats survive but
   are anonymous.

**Writing is asynchronous.** Events go into a buffer and are flushed in batches
(every 2 seconds, up to 128 rows). A chat never waits for the ledger.

**One bad row does not lose the batch.** If the database rejects a batch because
of the data (a Postgres data or constraint error, for example an event type the
database does not know yet), the gateway retries it row by row and drops only
the bad rows, logging each one. If the database itself is down, the batch is
dropped: retrying 128 rows one at a time against a dead database would only make
it worse.

## 3. Session summaries and `recall`

At the end of each run, the gateway saves a short summary of the session: the
user's opening ask and the final answer, each cut to 200 characters.

```
Find the September invoices for Globex in Tripletex and save a summary… →
Saved /reports/globex-2026-09.md with 14 invoices totalling NOK 412 300.
```

A week later Kari asks "what did we find for Globex last month?". The model calls
`recall`:

```json
{ "query": "Globex invoices", "k": 3 }
```

and gets her own matching sessions, newest and best first, each with a token to
load the detail through `expand_tool`.

### How the search works

Postgres full-text search turns text into a list of words.

- `to_tsvector('simple', summary)` turns
  "Find the September invoices for Globex" into
  `'find' 'the' 'september' 'invoices' 'for' 'globex'`.
- The query "Globex invoices" becomes `globex | invoices`: any word matches.
  Words under 3 letters are dropped, and only letters and digits pass, so user
  input can never inject search operators.
- `ts_rank` scores how well each summary matches. Results sort by that score,
  then by date.
- An empty or all-noise query ("what did we do?") returns the most recent
  sessions instead.

**Why `'simple'`?** It only lowercases and splits words. The English setting
would also cut word endings ("invoices" becomes "invoic") and drop common English
words. That garbles Norwegian. `simple` treats both languages the same.

**Why it must be written as a literal.** ds-config builds an index over exactly
`to_tsvector('simple', summary)`, like the index at the back of a book. Postgres
uses that index only when the query contains the identical expression. If
`'simple'` were passed as a parameter, Postgres could not see the match and would
read every row. A test checks that the SQL text stays the same.

### Privacy rules

- **You only recall your own sessions.** Every search filters by tenant **and**
  user. Kari cannot recall Ola's sessions.
- **Only the owner can replace a summary.** The session id comes from the client,
  so a crafted request could name someone else's session. The write then changes
  nothing and is reported as not owned, instead of overwriting Ola's memory with
  Kari's words.
- **Erasure.** When a user is deleted, ds-skill-sink deletes their summaries
  and saved facts.

`recall` is offered only when the summary store is connected. Otherwise it is
absent rather than present and always empty.

## 4. Saved facts (`remember` / `forget`)

When Kari asks the assistant to remember something ("Acme's fiscal year starts
in April"), the model calls `remember`. To drop one, it calls `forget`. Both are
handled inside the gateway, never by ds-tools. The facts are put in front of the
model at the start of every session, framed as Kari's own notes, not
instructions. `recall` answers "what did I do"; facts answer "what should you
always know about me".

- At most 30 facts per user, each one line of up to 300 characters.
- Private to the user: every read and write filters by tenant and user.
- `remember` is refused once any tool output is in the run, so text from a tool
  cannot plant a fact that reaches every later session.

## Prompt caching: memory for the provider

Every turn resends the whole prompt: tools, system prompt, transcript. Providers
can cache a stable beginning of a prompt and charge much less to read it again.
The harness makes that possible by declaring how stable each part is:

| Scope | Stable for | Example |
|---|---|---|
| `global` | everyone | the meta-tool schemas |
| `tenant` | one tenant | Acme's system prompt |
| `session` | one conversation | the working set, the transcript so far |
| `volatile` | this request only | everything else |

**The rule: scope may only go down along the prompt.** Something that changes
often must never come before something stable, or it would break the cache for
everything after it. A test enforces this.

The harness never places cache markers itself. Each provider adapter turns the
scopes into whatever its provider understands, because providers do caching in
incompatible ways.

**The biggest saving is the transcript.** In a ten-turn loop with large tool
results, input grows with every turn. Marking the transcript `session`-stable
means turn ten re-reads turns one to nine from cache instead of paying for them
again.

**A known cost.** Loading a tool changes the tools section, which comes before
the system prompt, so it invalidates the cached system prompt once. The working
set settles in the first few turns, so this costs a few cache writes early in a
conversation, not one every turn.

## Check yourself

1. Why are expand tokens in Valkey and not in Postgres?
2. A batch of 128 ledger rows fails because one row has an event type the
   database lacks. What is lost?
3. Kari's client sends Ola's session id. What happens to Ola's summary?
4. What breaks if the recall query uses `to_tsquery(?, ?)` with `'simple'` as a
   parameter?

<details><summary>Answers</summary>

1. They are short-lived, single-use nonces. Valkey gives native expiry and
   atomic "get and delete", shared across replicas. They are not records.
2. Only that row. The gateway retries the batch row by row and drops the rows
   the database rejects.
3. Nothing. The write is refused as not owned.
4. Postgres no longer sees the same expression as the index, so it scans every
   summary. Recall still works, but slowly.

</details>

Next: Lesson 6 — The self-improving loop
