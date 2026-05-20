---
name: openspec-review-external
description: "Package a review request for an external AI (codex, fresh Claude, GPT, etc.) to perform a second-opinion review. Writes a versioned prompt file to .orbit-runs/ and emits a short invocation snippet to chat. Use when the user wants cross-AI review."
license: MIT
compatibility: Requires openspec CLI. Findings come back as markdown files under `.orbit-runs/` and are ingested via `/opsx:address-reviews --from-file`.
metadata:
  author: openspec-orbit
  version: "0.1"
  capability: orbit-review-external
---
Package a review request for an external AI (codex, fresh Claude, GPT, etc.) to perform a second-opinion review of an OpenSpec change. The command emits **two things**: (a) a self-contained markdown prompt written to `openspec/changes/<change-name>/.orbit-runs/external-prompt-<as>-<TS>.md` (committed; the external AI reads it from the repo), and (b) a short invocation snippet to chat that tells the user what to paste into the external AI's session.

**Does NOT run the review and does NOT ingest findings.** The external AI does the review work. Ingestion is `/opsx:address-reviews --from-file <path>`. This command's job is solely to package the handoff.

**Input**: Optional change name and optional `--as proposal|system`. If omitted, change is selected via `AskUserQuestion`, mode is inferred from `tasks.md` state.

## Three execution disciplines (apply throughout this command)

These three disciplines are embedded in every orbit command as a self-contained reminder. They bracket the authoring lifecycle (authoring-time / modification-time / review-time).

**Read-before-reference (authoring-time)**. The prompt file you generate references project paths (`CLAUDE.md`, `openspec/lenses/perspectives.md`, etc.) and counts (iteration N, prior open findings, resolved-since-last). Read the actual files before citing them — don't assume `openspec/lenses/perspectives.md` exists; check. Don't fabricate iteration history; compute from `.orbit-runs/`. A prompt that names files that don't exist degrades the external AI's trust in the handoff.

**Change completeness (modification-time)**. The prompt file is written once per invocation. If you discover mid-generation that a section needs updating (e.g., iteration count was wrong because you missed a prior file), regenerate the whole file rather than partially overwriting. The prompt file becomes the canonical artifact for the external review; partial writes leak inconsistency.

**Pushback (review-time)**. Does not apply directly — this command generates packaging, not findings. But: the prompt instructs the external AI **not** to apply pushback discipline (`Do not push back on stale findings — pushback discipline is enforced on resolution, not review.`). This is deliberate: the external AI should flag what it observes; `/opsx:address-reviews` applies the pushback when ingesting findings.

## Steps

### 1. Resolve the change

If a change name is provided, use it. Otherwise:
- Run `openspec list --json` to get available changes.
- Use **AskUserQuestion** to let the user select.

State `Using change: <name>` at the top of the chat output.

### 2. Resolve the mode

Mode comes from `--as proposal|system` if specified. If omitted:

1. Read `openspec/changes/<name>/tasks.md`.
2. **All unchecked** → infer `proposal`.
3. **All checked + code changes visible** (heuristic: `git log` shows commits after the change directory was created) → infer `system`.
4. **Ambiguous** → use **AskUserQuestion** to let the user pick.

Emit a one-line inference note in chat output when `--as` was omitted: `Generating external-review prompt as \`<as>\` (inferred from tasks state).`

### 3. Detect uncommitted changes

Run `git status --porcelain`. If any output: include this warning in chat output before the recommended-session note:

```
Repo has uncommitted changes; external review will be against committed state.
```

(The external AI pulls the repo, so it only sees what's committed and pushed.)

### 4. Count iterations (per mode)

In `openspec/changes/<name>/.orbit-runs/`, count files matching `external-<as>-*.md` (findings files from prior external reviews in this mode — distinct from `external-prompt-<as>-*.md` which are prompt files).

- N matching files → this is iteration N+1.
- 0 matching files → iteration 1; note `first external review for this change in <as> mode`.

### 5. Load cycle context

For the "Cycle context" section of the prompt, gather:

- **Iteration N** (Step 4).
- **Prior internal review findings** still open: read the most-recent `review-<mode>-*.json` summary in `.orbit-runs/`; list count + short titles of unresolved findings.
- **Prior external review findings** still open: read existing `external-<as>-*.md` files in `.orbit-runs/`; cross-reference any prior `address-reviews-*.json` to mark resolved-or-not.
- **Resolved since last external review**: if a prior `address-reviews-*.json` exists, list its resolved-finding titles.

If `.orbit-runs/` is absent or has no prior content: omit the "open findings" sublists; the cycle-context section just shows iteration 1.

### 6. Compute the recommended-session note

Read the `**Reviewer**:` field from existing `external-<as>-*.md` files in `.orbit-runs/` (these record which AI did each prior review). Pick the phrasing:

- **Iteration 1**: `Fresh session recommended — first external pass; sets independent baseline. Pick any AI (codex / fresh Claude / GPT / etc.).`
- **Iteration 2**: `Fresh session in a DIFFERENT AI than iter 1's reviewer recommended (model diversity catches different blind spots). If iter 1 was <prior reviewer>, try <suggest different model>.`
- **Iteration 3+**: `Either (a) carry context from a same-AI prior session — lets that reviewer verify its earlier findings were actually addressed (ideal when concerns from that reviewer dominated prior iterations); or (b) fresh session in a previously-unused AI — maximum independence (ideal when looking for net-new issues). For this iter, consider <specific suggestion based on prior-reviewer pattern>.`

Same-vs-fresh trade-off (mention briefly in the recommendation when relevant): **fresh sessions maximize independence (better at finding net-new issues); same-AI continuation sessions maximize verification (better at checking whether prior findings were actually addressed).**

### 7. Write the prompt file

Compose the full self-contained prompt (per the reference template below) and write to:

```
openspec/changes/<change-name>/.orbit-runs/external-prompt-<as>-<TS>.md
```

`<TS>` is ISO-8601 with hyphens (e.g., `2026-05-18T14-35-23Z`). Create `.orbit-runs/` if it doesn't exist. The file is **committed**, not gitignored.

Mode-specific content:

- **"What to read for THIS review"** lists files appropriate to the mode (proposal mode emphasizes the change directory artifacts; system mode adds `git diff`, codebase paths, lens files).
- **"What to look for"** enumerates the 9 proposal-mode passes or the 7 system-mode passes (see below).

The **"Output format"** block inside the prompt MUST appear verbatim — the section headers (`## CRITICAL` / `## WARNING` / `## SUGGESTION`) and the field labels (`**File**:`, `**Description**:`) are what `/opsx:address-reviews --from-file` parses. Deviating breaks ingestion.

### 8. Emit the chat invocation snippet

Print to chat, in this exact order:

1. **(optional)** Mode-inference note when `--as` was omitted: `Generating external-review prompt as \`<as>\` (inferred from tasks state).`
2. **(optional)** Uncommitted-changes warning when applicable: `Repo has uncommitted changes; external review will be against committed state.`
3. **(required)** Recommended-session note: `Recommended session: <phrasing from Step 6>`
4. **(required)** The prompt file path: `Prompt: openspec/changes/<change-name>/.orbit-runs/external-prompt-<as>-<TS>.md`
5. **(required)** A 1–3 sentence copy-paste-ready invocation: `Pull <repo URL> and read <prompt-file-path>. Follow its instructions; write findings to the path specified inside.`
6. **(required)** The eventual findings path: `When findings come back: /opsx:address-reviews --from-file openspec/changes/<change-name>/.orbit-runs/external-<as>-<TS>.md (TS will be set by the external AI when it writes).`

No other items. Required items always appear in the specified order.

## Reference prompt template

The full template for the file written in Step 7 lives at `references/prompt-template.md`. Read that file when composing the prompt. The template is verbatim — preserve named sections and especially the "Output format" block (the `## CRITICAL` / `## WARNING` / `## SUGGESTION` headers + `**File**:` / `**Description**:` field labels) so `/opsx:address-reviews --from-file` parses cleanly.

## Mode-specific sections

Mode-specific content (the "What to read for THIS review" file list and the "What to look for" pass list) lives at `references/mode-sections.md`. Read that file and substitute the appropriate block (proposal: 9 passes / system: 7 passes) into the template.

## Worked example (chat output, iter 5 proposal-mode review of `bootstrap-openspec-orbit`)

```
Generating external-review prompt as `proposal` (inferred from tasks state).
Repo has uncommitted changes; external review will be against committed state.

Recommended session: Iter 5 — either (a) carry context from your iter-3 codex
chat (codex verifies whether its iter-3 findings actually landed after the rename
+ discipline-add), or (b) fresh Claude session for maximum independence
(better at catching cleanup-residue from the most recent substantive edits).
For this iter, (b) is the higher-signal choice given how much changed after iter 4.

Prompt: openspec/changes/bootstrap-openspec-orbit/.orbit-runs/external-prompt-proposal-2026-05-18T14-35-23Z.md

To run: Pull https://github.com/las-sal/openspec-orbit and read
openspec/changes/bootstrap-openspec-orbit/.orbit-runs/external-prompt-proposal-2026-05-18T14-35-23Z.md.
Follow its instructions; write findings to the path specified inside.

When findings come back: /opsx:address-reviews --from-file
openspec/changes/bootstrap-openspec-orbit/.orbit-runs/external-proposal-<TS>.md
(<TS> will be set by the external AI when it writes.)
```

## Out of scope

The command does not run the review and does not ingest findings:

- **Running the review**: the external AI does it. This command is packaging.
- **Ingesting findings**: `/opsx:address-reviews --from-file <path>` ingests; this command emits the path the user will pass to that command later.

## Graceful degradation

- **No `.orbit-runs/`** → create it as part of writing the prompt file; iteration is 1.
- **No prior internal review summary** → cycle-context section omits the "open internal findings" sublist.
- **No prior external review** → recommended-session note uses iter 1 phrasing; cycle context omits "open external findings".
- **No lenses files** → "Project context (read first)" line for those still appears (the `(if present)` qualifier handles the absence); external AI will see they're absent when it pulls the repo.
- **No git remote / repo URL unknown** → emit the local path instead of a URL and add a note: `If you don't have access to this repo, copy it to a shared location and update the invocation.`
