---
title: Understand the course model
---
## What AIC stores

A course is a small, ordered collection of content files plus shared course metadata.

- **Course:** title, description, folder, cover, theme, status, and visibility.
- **Step:** one learning moment with its own title.
- **Column:** one content area inside a step — either Markdown or an image.
- **File:** every content area is stored independently, which keeps editing and permissions predictable.

This model lets you revise one part without rebuilding the whole course.

<!-- ds-course-column:2 type=markdown -->

## Course files in DS File

```mermaid
%%{init: {"treeView": {"showIcons": true}}}%%
treeView-beta
  courses/
    public_creating-courses-in-ai-commons/
      cover.webp ## Course cover
      step-001-column-001-hash.md ## Welcome
      step-002-column-001-hash.md ## Course model
      step-002-column-002-hash.md ## Folder tree
```

The folder is the stable course boundary; every column is stored as an independent file.
