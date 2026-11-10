---
name: inspect
slug: inspect
domain: tools
description: Playbook for the inspect tool, covering model reads of stored images and documents, targeted questions, supported formats and limits, long-answer overflow, and treating the answer as a reading rather than ground truth.
when_to_use: Read a stored image or document whose bytes you cannot read directly, such as a PNG, scanned PDF, or spreadsheet, by asking a question about it.
prefer_skills: []
related_tools: [inspect, generate_image, frames, plot, cat, ls]
examples: []
---

`inspect(path, question)` sends a `/files/<uuid>` file to a multimodal
model and returns the answer as text. It reads the file under your own
access and leaves it untouched.

## What it reads

- Images: png, jpeg, gif, webp (stored uploads, `generate_image` results,
  `frames` output).
- Documents: pdf, docx, doc, xlsx, xls, csv, html, txt, md.
- Plot visuals; address one cell as `/files/<uuid>/cells/<id>`.
- The model enforces its own per-format size ceilings, which are lower
  for images and text-based documents. A refusal is `validation` and
  names the type or limit that applied.
- Video and audio are not read: extract stills with `frames`, or speech
  with `transcribe`, then work from those.

## Rules

- Ask a targeted question (at most 1024 chars). The default, "Describe
  this file in detail.", is a fallback; "does the chart's y-axis start at
  zero?" buys far more per call.
- Prefer `cat` for plain text you can read directly; use inspect when
  the bytes are binary, scanned, or need layout understanding.
- One file per call. Comparing two files means two inspects and your own
  synthesis.
- Synchronous. The call already gets a 30 s floor; raise `timeout_ms`
  for long multi-page documents.
- Long answers (beyond about 16,000 chars) are stored as a text file
  (`inspections/...`, tagged `kind=inspection`) and returned as a
  `/files/<uuid>` reference with the opening lines. `cat` it for the rest.
- The answer is a model's reading, not ground truth. Treat small text and
  counts in cluttered scenes with scepticism, and re-ask with a narrower
  question when the detail matters.
- Elevated cost tier: a real model call per invocation.
