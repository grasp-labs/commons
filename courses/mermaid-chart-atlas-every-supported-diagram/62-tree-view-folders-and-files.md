---
title: 'Tree view: folders and files'
---
## Tree view: folders and files

**Atlas example 30 of 44**

Use a tree view to present a repository, information architecture, or other literal hierarchy.

### Core Mermaid elements
- treeView-beta starts the tree.
- Indentation defines parent and child entries.
- A trailing / visually identifies a folder.
- Plain labels represent files or leaf items.

### Build it well
1. Start at a meaningful root.
2. Use consistent indentation.
3. Show only branches relevant to the lesson.
4. Prefer mindmap when the hierarchy is conceptual rather than literal.

> Tree view answers where something lives.

<!-- ds-course-column:2 type=markdown -->

## Working example

```mermaid
treeView-beta
  platform/
    apps/
      web/
        src/
          features/
          shared/
        package.json
      api/
        modules/
        services/
    packages/
      design-system/
      observability/
    README.md
```

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
