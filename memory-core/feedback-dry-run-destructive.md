---
name: feedback-dry-run-destructive
description: preview file-touching or outward-facing actions before executing them
metadata:
  type: feedback
  scope: universal
  lastVerified: 2026-06-25
  tags: [safety, destructive-ops, automation]
---

Default any operation that modifies files outside the current repo, deletes data, or publishes
to an external service to a **dry-run / preview first**, then execute on confirmation.

**Why:** hard-to-reverse and outward-facing actions can't be cleanly undone; approval in one
context does not extend to the next.

**How to apply:** tooling that mutates other projects (e.g. retrofit/migration) ships a
`--dry-run` that prints the exact diff and changes nothing by default. Back up before replacing
(`*.mc-bak`). Confirm before sending content to any external/cached/indexed service.
