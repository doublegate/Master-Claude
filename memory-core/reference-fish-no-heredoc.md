---
name: reference-fish-no-heredoc
description: fish shell has no heredoc syntax; author multi-line output with printf or tee
metadata:
  type: reference
  scope: universal
  lastVerified: 2026-06-25
  tags: [shell, fish, scripting]
---

The fish shell has **no heredoc** (`<<EOF`) syntax.

**How to apply:** to write multi-line content from a shell step, use `printf '...\n...' > file`
or pipe into `tee`, not a heredoc. Shell scripts intended to be portable should target POSIX
`/bin/sh` and avoid heredocs anyway, so they run identically regardless of the interactive
shell. Relevant to the user's default fish environment and to all `bin/` tooling here.
