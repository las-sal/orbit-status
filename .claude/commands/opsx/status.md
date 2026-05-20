---
name: "OPSX: Status"
description: Surface the status of an openspec-orbit project — what's active, what phase each change is in, what needs attention, where the developer is in the workflow.
category: Workflow
tags: [workflow, status, orbit]
---
Surface the status of the current openspec-orbit project. Read-only — never mutates state. Invokes the `opsx-status` binary and interprets its output conversationally.

## What this command does

1. **Shell out** to `opsx-status --json` at `.claude/skills/openspec-status/bin/opsx-status` (relative to the orbit overlay's skill directory).
2. **Parse the JSON** — top-level keys `project / focus / active / exploring / recent / totals`.
3. **Interpret** for the user with conversational context, not raw fields:
   - Lead with the `focus.summary` sentence and `focus.recommended_next` (orbit's own recommendation).
   - Expand attention signals with type-aware context (markers → suggest `/opsx:address-reviews`; stale_review → suggest a fresh review; audit_divergence → suggest `/opsx:audit-drift`).
   - Surface secondary threads briefly; offer to drill into any of them with `--change <name>`.
   - Note "(orbit project)" status iff `is_orbit_project: true`.
4. **Offer the next action.** Don't auto-run — per orbit issue `#7`, never auto-invoke an opsx command without explicit user authorization. Surface the recommendation and let the user type it (or pick something else from the workflow inflection-point menu per orbit issue `#15`).

## How to invoke

```
/opsx:status                        # surface current state
/opsx:status --detail               # expand per-change details (review history breakdown, attention text, source field, next_unchecked task)
/opsx:status --change <name>        # pin focus to a specific thread
/opsx:status --limit N              # cap recent[] archived listing
```

The flags are pass-through to the binary.

## Interpretation rules

### Surfacing the recommendation

The JSON's `focus.recommended_next` is orbit's own opinion (tier 1 reads from the latest `.orbit-runs/*.json`'s `next_recommended` field; tier 2 synthesizes; tier 3 is the empty-project fallback). When presenting in chat:

- **Quote the `reason` field verbatim** — that's orbit's voice; don't paraphrase. The string may be either a parseable `/opsx:<verb> ...` token (in which case `command` + `args` are populated) or prose with multiple alternatives (in which case `command`/`args` are null and `reason` carries the full text).
- **Show the resolved command + args** if non-null.
- **Under `--detail`**, mention the `source` field so the user can see which tier and which JSON / rule drove the recommendation.

### Attention signal handling

Each `attention[]` entry has a closed-enum `type`. Render contextually:

| Type | Context to surface |
|---|---|
| `unresolved_marker` | Suggest `/opsx:address-reviews <change-name>` — markers signal review-cycle work isn't done |
| `stale_review` | Suggest a fresh `/opsx:review` — artifacts have moved since the last review pass |
| `audit_divergence` | Suggest `/opsx:audit-drift` to investigate — orbit detected drift in captured knowledge |
| `task_blocked` | (v2 — not yet emitted) |

Under `--detail`, expand each entry with its full `text` / `since` / `count` field.

### Multi-thread workflows

When `secondary_threads[]` is non-empty (multiple active or exploring threads), present them after the primary thread's narrative but BEFORE the recommendation. Mention that `--change <name>` can pin focus to any of them.

### Plain-openspec degradation

When `project.is_orbit_project` is `false`:

- Don't mention orbit-specific concepts (review iterations, attention types beyond markers/stale)
- `review_history` will be absent from `ChangeRecord` — don't try to surface it
- `recommended_next.source` will be absent even under `--detail` — don't reference tier semantics

The CLI handles these omissions; the slash command just shouldn't reach for missing fields.

### Workflow inflection-point pattern (per orbit issue #15)

Don't end the response with a single "Run /opsx:apply" suggestion. Instead, surface the recommendation AND the legitimate alternatives at this point in the workflow:

```
You are applying bootstrap-orbit-status-cli.
  44/79 tasks · 5 attention

Next: /opsx:apply bootstrap-orbit-status-cli
  "Partial tasks; continue applying."

What you can do:
  (A) continue applying — /opsx:apply bootstrap-orbit-status-cli
  (B) address the 5 attention items — /opsx:address-reviews ...
  (C) re-review with fresh context — /opsx:review --fresh ...
```

The menu adapts to the current workflow point (after explore, after propose, after review, etc.). The recommendation lights up the "default" option; alternatives are honest about what else is reasonable.

## Disciplines

Three orbit disciplines apply:

- **Read-before-reference** — if a finding cites a file:line, read it before quoting.
- **Pushback** — when the user asks about state, verify against current orbit-status output rather than restating cached context.
- **Don't auto-invoke** (orbit issue `#7`) — surface the recommendation; let the user type it.

## Binary location

`.claude/skills/openspec-status/bin/opsx-status` — shipped via the orbit overlay. `jq` is a hard dependency.

See `.claude/skills/openspec-status/SKILL.md` for the full flag surface and JSON schema documentation.
