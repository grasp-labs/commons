---
name: "extract"
slug: "extract"
domain: "tools"
description: "Playbook for the extract tool: pulling a stored document's text verbatim with no model, size limits, overflow to a text file, and routing scans to inspect."
when_to_use: "You need the actual words of a stored document (/files/<uuid>), e.g. a contract, invoice or report PDF, rather than an answer about it. Try it before inspect."
prefer_skills: []
related_tools: [extract, inspect, cat, grep, ls, find]
examples: []
---

`extract(path)` returns the text layer of a stored document exactly as
written. No model is involved, so there is no paraphrase, invented line
item or silent truncation, and the same file gives the same text. It is
the cheap first step for documents (cost 1, below `inspect`).

Three tools, one path, three contracts: `cat` returns bytes, `extract`
returns text, `inspect` returns an answer.

## Input

- `path`: `/files/<uuid>`; a trailing `/content` is accepted. Find the
  UUID with `ls /files/<prefix>/`, `find` or `grep` first.
- Supported formats are listed in the tool description (the backend is
  PDF text extraction). An unsupported type fails as `validation` naming
  the actual type.
- Documents up to 64 MiB. Larger fails as `validation`; the message says
  whether `inspect` can read it (it answers questions about large files
  but does not return their text) or that a split or smaller copy is
  needed.

## Output

- Text that fits the inline budget (about 16,000 characters) is returned
  as-is; nothing is written.
- Longer text is stored whole as a new `text/plain` file. The result is a
  stub: the character count, `Full text stored as /files/<id>`, and the
  opening ~1000 characters, with the id also in `artifact_file_id`. Work
  on that file with `grep` for passages or `cat /files/<id>/content` with
  `offset` paging (see the `cat` playbook).
- If storing fails, you get the text cut to the inline budget instead;
  the tail is missing.

## No text layer

A scan or photographed page has nothing to extract. This is a success,
not an error: the result says the file "has no extractable text layer"
and, when the deployment has a vision backend, names `inspect(path)`.
Detect that message and switch to `inspect` instead of retrying. Without
a vision backend the message says no tool on this deployment reads a scan.

## Pitfalls

- `extract` is a read: the source file is untouched and the overflow file
  holds only text you could already read. It works in plan posture.
- The tool is registered only where its extraction binary is installed;
  if `extract` is missing from the catalogue, use `inspect`.
- It asks for at least 30 s when `timeout_ms` is omitted; large files
  need it.
