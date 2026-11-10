---
name: generate_image
slug: generate_image
domain: tools
description: Playbook for the generate_image tool, covering results stored as platform files rather than inline bytes, the generate then inspect verification loop, timeout and prompt limits, aspect ratio and seed, and container path targeting.
when_to_use: Create an image from a text prompt. The result is a stored platform file, never inline bytes.
prefer_skills: []
related_tools: [generate_image, inspect, ls, info, rm]
examples: []
---

`generate_image` returns a `/files/<uuid>` reference
(`artifact_file_id`); you never see the bytes. The stored object is an
ordinary DS File record (PNG, tagged `kind=generated-image`), so `ls`,
`info`, and `rm` all apply.

## The generate → verify loop

You cannot trust a generation sight unseen. After generating, call
`inspect(path)` with a question targeting what matters ("is there any
text? how many people?") before presenting the result as done. This is
the intended composition, not an extra.

## Rules

- Generation takes tens of seconds, so set `timeout_ms` to 30000 or more.
- The prompt is 1–2048 chars. Describe subject, style, and constraints;
  the prompt is the only thing sent to the image backend.
- `aspect_ratio` is one of `1:1` (default), `16:9`, `9:16`, `3:2`,
  `2:3`, `5:4`, `4:5`, `21:9`, `9:21`. `format` is `png` only.
- `seed` (integer ≥ 0) makes generation reproducible. Record it when the
  user may want variations of a kept result.
- `path` is a container, not a filename: `/files` (default) or
  `/files/<prefix>`. Images land at `[<prefix>/]generated/<yyyy>/<mm>/…`.
- A prompt the backend filters fails as `validation`. Rephrase rather
  than retrying it unchanged.
- Restricted tier: real model cost per call. Iterate on the prompt in
  your head, not by burning generations, and `inspect` before
  regenerating so a retry is grounded in what was actually wrong.
- Data note: the prompt is processed in a US region; the image itself is
  stored in-region.
