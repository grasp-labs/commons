---
name: frames
slug: frames
domain: tools
description: Playbook for the frames tool, covering extracting stills from a stored video as image files, choosing count versus explicit timestamps, the transcribe plus frames plus inspect composition for watching a video, and managing the files it creates.
when_to_use: See inside a stored video. Extracts still frames as image files; inspect them to get eyes on the footage.
prefer_skills: []
related_tools: [frames, inspect, transcribe, ls, rm]
examples: []
---

`frames(path)` decodes a `/files/<uuid>` video and stores up to 20
stills as PNG files. The output lists every created `/files/<uuid>`
path; each is an ordinary file you `inspect`.

## Choosing frames

- `count=N` (1–20, default 5): midpoints of N equal segments. `count=1`
  is the middle of the video, never the often-black first or last frame.
- `timestamps=[…]` (seconds, at most 20, overrides `count`): exact
  moments. Use these when the transcript or the user tells you *when*
  something happens. A timestamp past the end of the video fails as
  `validation`.

## The video loop

`transcribe` tells you what is said and when; `frames` at the
interesting timestamps plus `inspect` per frame tells you what is shown.
That composition is the platform's answer to "watch this video". Budget
it: each extraction writes N files (restricted tier), and each inspect is
a model call.

## Rules

- Start with few frames (3–5) and go targeted with timestamps rather
  than maxing `count` and inspecting 20 images.
- The video fetch cap is 128 MiB; input that cannot be decoded fails as
  `validation`.
- The call gets a 30 s floor; raise `timeout_ms` for large videos or
  many frames.
- Frames persist as ordinary files, keyed
  `frames/<yyyy>/<mm>/<source-uuid>/frame-NNN.png` and tagged
  `kind=video-frame`, `source=<source-uuid>`. `rm` them when they were
  scaffolding; keep them when they are the deliverable.
