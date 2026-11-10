---
name: transcribe
slug: transcribe
domain: tool
description: Playbook for the transcribe tool, covering speech-to-text over stored audio and video, inline versus stored artifact results, the synchronous duration ceiling, language tag handling, treating machine transcripts with scepticism, and cost.
when_to_use: Get the speech out of a stored audio or video file as text. It is the only way to hear media; cat on an MP3 returns unreadable bytes.
prefer_skills: []
related_tools: [transcribe, frames, inspect, cat, ls]
examples: []
---

`transcribe(path)` runs speech-to-text on a `/files/<uuid>` media file.
Short transcripts return inline. Long ones (beyond about 16,000 chars)
are stored as a text file (`artifact_file_id`, tagged `kind=transcript`)
with the opening lines in the output; `cat` that file for the full text.

## Rules

- Synchronous, and it already runs on the largest invocation budget the
  dispatcher grants. Raising `timeout_ms` does not help. Media that
  cannot finish in time is refused as `validation`; clip or split it and
  transcribe each part.
- The fetch cap is 64 MiB. Duration, not size, decides whether it
  finishes, so prefer an audio-only file over full video when both
  exist.
- `language` is a BCP-47 tag (`en-US`, `nb-NO`). Omit it for automatic
  detection, and set it only when you know the language, since a wrong
  tag degrades the transcript silently.
- The transcript is machine-read speech. Names, numbers, and domain terms
  are the usual casualties. Quote it as a transcript and verify
  load-bearing details with the user before acting on them.
- Video with no speech yields an empty or trivial transcript. That
  answers "what is said", not "what is shown"; for visuals use `frames`
  then `inspect`.
- Restricted tier with external per-use cost. Transcribe once and keep
  the artifact; do not re-run on the same file.
- Data note: media is staged in the tenant's own storage bucket for the
  job and deleted afterwards (best effort).
