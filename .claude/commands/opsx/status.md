---
name: "OPSX: Status"
description: Surface the status of an openspec-orbit project — what's active, what phase each change is in, what needs attention, where the developer is in the workflow.
category: Workflow
tags: [workflow, status, orbit]
---
Surface the status of the current openspec-orbit project. Read-only — never mutates state.

(Full slash command body coming in chunk 5 of `bootstrap-orbit-status-cli` — tasks 14.1–14.3, 15.3. For now, this file exists as a stub so the slash command discovery doesn't fail; the chunk-5 work fleshes out interpretation guidance, behavior on tier-2 vs tier-1 recommendations, when to expand attention details in chat, etc.)

## Interim behavior (chunk 1)

Until the chunk-5 interpretation rules land, invoke the underlying binary directly to see status output:

```bash
# Human-readable view
.claude/skills/openspec-status/bin/opsx-status

# Machine-readable JSON
.claude/skills/openspec-status/bin/opsx-status --json

# Detailed view
.claude/skills/openspec-status/bin/opsx-status --detail
```

See `.claude/skills/openspec-status/SKILL.md` for the full flag surface and JSON schema.
