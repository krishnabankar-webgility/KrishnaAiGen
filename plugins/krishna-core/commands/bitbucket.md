---
description: 'Bitbucket work on unify-enterprise: authenticated remote, push a branch, create or review a PR'
argument-hint: '[e.g. "push UD-33334-krishna and open a PR"]'
---

Delegate this request to the **`bitbucket-automation`** subagent using the Agent tool.

The subagent must load these skills before acting: `git-sync`, then `bitbucket-unify-enterprise`.

If the request below is empty, ask what is needed rather than guessing.

## Request

$ARGUMENTS
