---
name: "OPSX: Review External"
description: Package a review request for an external AI (codex, fresh Claude, GPT, etc.) to perform a second-opinion review
category: Workflow
tags: [workflow, review, external, orbit]
---
Package a review request for an external AI to perform a second-opinion review of an OpenSpec change. Writes a self-contained markdown prompt to `openspec/changes/<change-name>/.orbit-runs/external-prompt-<as>-<TS>.md` (committed) and emits a short invocation snippet to chat.

**Does NOT run the review. Does NOT ingest findings.** Ingestion is `/opsx:address-reviews --from-file <path>` after the external AI returns findings.

## Input

`/opsx:review-external [<change-name>] [--as proposal|system]`

- `<change-name>` — optional. If omitted, prompts via `openspec list --json`.
- `--as proposal|system` — optional. Inferred from `tasks.md` state if omitted (unchecked → proposal; all checked + code → system; ambiguous → prompts).

## What it does

Invokes the `openspec-review-external` skill, which:

1. Resolves change name and mode (mode-inference from `tasks.md` when `--as` omitted)
2. Checks `git status` for uncommitted changes; warns in chat if present
3. Counts iterations per mode (count of prior `external-<as>-*.md` files in `.orbit-runs/`)
4. Loads cycle context from prior `.orbit-runs/` (open internal/external findings, resolved-since-last)
5. Computes a recommended-session note based on iteration number + prior-reviewer history
6. Writes the full self-contained prompt to `openspec/changes/<change-name>/.orbit-runs/external-prompt-<as>-<TS>.md`
7. Emits a short invocation snippet to chat (recommended-session line, prompt path, paste-ready invocation, eventual findings path)

The prompt file is **committed** (so the external AI can read it from the repo). After running this command, push the prompt file to the remote before pasting the invocation snippet into the external AI.

## Output

Chat output (in this exact order):

```
(optional) Generating external-review prompt as `<as>` (inferred from tasks state).
(optional) Repo has uncommitted changes; external review will be against committed state.
Recommended session: <fresh / continue-same-AI / different-AI suggestion>
Prompt: openspec/changes/<change-name>/.orbit-runs/external-prompt-<as>-<TS>.md

To run: Pull <repo URL> and read <prompt-file-path>. Follow its instructions; write findings to the path specified inside.

When findings come back: /opsx:address-reviews --from-file openspec/changes/<change-name>/.orbit-runs/external-<as>-<TS>.md (<TS> set by external AI when it writes).
```

The external AI's findings file follows the orbit external-review markdown format (see SKILL.md "Output format" block) so `/opsx:address-reviews --from-file` parses cleanly.

## Execution disciplines

- **Read-before-reference** — verify project-context files and counts before citing them in the prompt.
- **Change completeness** — regenerate the prompt file if a mid-generation update is needed; do not partially overwrite.
- **Pushback** — N/A for this command; deliberately instructs the external AI NOT to apply pushback (so it flags everything it observes; `/opsx:address-reviews` handles pushback on ingest).

See `.claude/skills/openspec-review-external/SKILL.md` for full prompt template, mode-specific pass lists, and recommended-session logic.
