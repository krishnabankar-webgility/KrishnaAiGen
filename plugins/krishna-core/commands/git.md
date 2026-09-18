---
description: 'Git commit, push, merge, branch sync (master-first for KrishnaAiGen; opt-in develop sync)'
argument-hint: '[commit | push | sync develop with master | status]'
---

Delegate this request to the **`git-automation`** subagent using the Agent tool.

The subagent must load these skills before acting: `git-sync`.

If the request below is empty, ask what is needed rather than guessing.

## Request

$ARGUMENTS
