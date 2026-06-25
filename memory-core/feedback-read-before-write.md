---
name: feedback-read-before-write
description: always inspect a file before editing or overwriting it
metadata:
  type: feedback
  scope: universal
  lastVerified: 2026-06-25
  tags: [files, safety, editing]
---

Always Read (or Glob/Grep) a file's current content before editing or overwriting it.

**Why:** blind writes destroy context and silently revert others' work; if what you find
contradicts how the task described the file, that contradiction is a signal to surface, not
overwrite.

**How to apply:** for existing files use Edit (targeted) over Write (full replace); reserve
Write for genuinely new files. Before deleting/overwriting, confirm the target is what you
expect and that you created it or were told to change it.
