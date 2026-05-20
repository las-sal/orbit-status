---
name: openspec-archive-change
description: Archive a completed change in the experimental workflow. Use when the user wants to finalize and archive a change after implementation is complete.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.3.1"
---
Archive a completed change in the experimental workflow.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **If no change name provided, prompt for selection**

   Run `openspec list --json` to get available changes. Use the **AskUserQuestion tool** to let the user select.

   Show only active changes (not already archived).
   Include the schema used for each change if available.

   **IMPORTANT**: Do NOT guess or auto-select a change. Always let the user choose.

2. **Check artifact completion status**

   Run `openspec status --change "<name>" --json` to check artifact completion.

   Parse the JSON to understand:
   - `schemaName`: The workflow being used
   - `artifacts`: List of artifacts with their status (`done` or other)

   **If any artifacts are not `done`:**
   - Display warning listing incomplete artifacts
   - Use **AskUserQuestion tool** to confirm user wants to proceed
   - Proceed if user confirms

3. **Check task completion status**

   Read the tasks file (typically `tasks.md`) to check for incomplete tasks.

   Count tasks marked with `- [ ]` (incomplete) vs `- [x]` (complete).

   **If incomplete tasks found:**
   - Display warning showing count of incomplete tasks
   - Use **AskUserQuestion tool** to confirm user wants to proceed
   - Proceed if user confirms

   **If no tasks file exists:** Proceed without task-related warning.

4. **Assess delta spec sync state**

   Check for delta specs at `openspec/changes/<name>/specs/`. If none exist, proceed without sync prompt.

   **If delta specs exist:**
   - Compare each delta spec with its corresponding main spec at `openspec/specs/<capability>/spec.md`
   - Determine what changes would be applied (adds, modifications, removals, renames)
   - Show a combined summary before prompting

   **Prompt options:**
   - If changes needed: "Sync now (recommended)", "Archive without syncing"
   - If already synced: "Archive now", "Sync anyway", "Cancel"

   If user chooses sync, use Task tool (subagent_type: "general-purpose", prompt: "Use Skill tool to invoke openspec-sync-specs for change '<name>'. Delta spec analysis: <include the analyzed delta spec summary>"). Proceed to archive regardless of choice.

5. **Perform the archive**

   Create the archive directory if it doesn't exist:
   ```bash
   mkdir -p openspec/changes/archive
   ```

   Generate target name using current date: `YYYY-MM-DD-<change-name>`

   **Check if target already exists:**
   - If yes: Fail with error, suggest renaming existing archive or using different date
   - If no: Move the change directory to archive

   ```bash
   mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>
   ```

6. **Display summary**

   Show archive completion summary including:
   - Change name
   - Schema that was used
   - Archive location
   - Whether specs were synced (if applicable)
   - Note about any warnings (incomplete artifacts/tasks)

**Output On Success**

```
## Archive Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Archived to:** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs:** ✓ Synced to main specs (or "No delta specs" or "Sync skipped")

All artifacts complete. All tasks complete.
```

**Guardrails**
- Always prompt for change selection if not provided
- Use artifact graph (openspec status --json) for completion checking
- Don't block archive on warnings - just inform and confirm
- Preserve .openspec.yaml when moving to archive (it moves with the directory)
- Show clear summary of what happened
- If sync is requested, use openspec-sync-specs approach (agent-driven)
- If delta specs exist, always run the sync assessment and show the combined summary before prompting

---

# Orbit additions

The sections below describe orbit-specific additions on top of upstream's archive flow. The upstream content above is unchanged. Orbit adds a **pre-archive `audit-drift` sweep**, a `--skip-audit` opt-out, an **unresolved `@review:` marker warning**, an **archive run summary** written to `.orbit-runs/`, and a small set of edge-case behaviors.

## Three execution disciplines (apply throughout this command)

**Read-before-reference (authoring-time)**. The archive run summary cites the pre-archive audit findings, user decision, and sync-specs results. Read the audit-drift output and the sync-specs assessment before writing the summary — don't infer counts from intent. The summary becomes the audit trail for the archived change; false claims corrupt later inspection.

**Change completeness (modification-time)**. The archive flow modifies multiple artifacts: it moves the change directory, runs `sync-specs` (which writes to baseline), and writes the archive run summary. Apply these fully: a moved change should not leave dangling references in baseline; a sync-specs run should not leave delta-only requirements unreflected in baseline. Sweep after each step to confirm completion before proceeding to the next.

**Pushback (review-time)**. The pre-archive audit produces findings. Before presenting them to the user, verify each against current state (audit-drift's own pushback discipline applies, but apply a second-pass check at the archive layer): is the finding still applicable given any commits since the audit ran in the current session? Stale findings get a note in the summary, not a re-prompt.

## NEW Step 1.5 — Unresolved `@review:` marker warning

After upstream Step 1 (selection) but before Step 2 (artifact completion check):

Grep the change directory for `@review:` markers:

```bash
grep -rn "@review:" openspec/changes/<change-name>/
```

If any markers are found, warn:

```
N unaddressed `@review:` markers will land in archive — convert to `@todo:` or address before archiving?
```

Prompt via `AskUserQuestion`:

- **Address now** — halt the archive; user runs `/opsx:address-reviews openspec/changes/<change-name>/` to resolve before re-invoking.
- **Convert to `@todo:`** — run a bulk transform replacing each `@review:` with `@todo:` in place (preserves the content as known follow-up rather than unresolved review).
- **Proceed** — archive with the markers in place; record this decision in the archive run summary.

If no markers, proceed without prompting.

## NEW Step 3.5 — Pre-archive audit-drift sweep

After upstream Step 3 (task-completion check) but before Step 4 (sync-specs):

**Unless `--skip-audit` is set**, invoke `/opsx:audit-drift` as a library function with context `pre-archive` and the current change name. Wait for the findings.

### Branching on audit findings

| Audit state | Action |
|---|---|
| **≥1 CRITICAL findings** | Prompt user via `AskUserQuestion`: "Address now / Proceed with archive / Abort?" Show the full audit findings to inform the choice. |
| **No CRITICAL, only WARNING/SUGGESTION** | Proceed without prompting; warnings logged in the archive run summary. |
| **No findings** | Proceed without prompting; clean audit recorded in summary. |
| **Audit failed to run** (parse error, internal exception) | Proceed with a warning. Archive run summary records `audit.ran: false` with the failure reason. Do NOT block on audit-tool failures. |

### Prompt outcomes (for the ≥1 CRITICAL case)

- **Address now** → archive does not proceed. User fixes the drift issues and re-invokes `/opsx:archive`. No summary written this run.
- **Proceed with archive** → archive proceeds normally. Summary records `user_decision: proceeded_despite_critical`.
- **Abort** → archive is cancelled. No move, no sync-specs, no summary.

### `--skip-audit` flag

When `/opsx:archive --skip-audit <name>` is invoked, the entire Step 3.5 audit is skipped. The archive run summary records `audit_skipped_via_flag: true`. Use case: the user has just run `/opsx:audit-drift` manually and doesn't need to repeat it.

## NEW Step 5.5 — Archive run summary

After upstream Step 5 (move-to-archive) completes successfully, write a JSON summary to:

```
openspec/changes/archive/<YYYY-MM-DD>-<change-name>/.orbit-runs/archive-<TS>.json
```

Where `<YYYY-MM-DD>` is the date prefix upstream's move step added (per `mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>` at Step 5). The `.orbit-runs/` directory should be present already — it moved with the change content. If somehow absent, create it.

Full schema lives at `references/archive-summary-schema.md` — read that file when composing the summary.

## `.orbit-runs/` moves with the change

Upstream Step 5's `mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>` already moves the entire change directory, including `.orbit-runs/`. No additional handling required — `.orbit-runs/` is just a subdirectory of the change.

All prior internal-run summaries (`review-*-*.json`, `audit-drift-*.json`, `address-reviews-*.json`) and external-review findings (`external-*.md` + `external-prompt-*-*.md`) persist in the archived location at `openspec/changes/archive/<YYYY-MM-DD>-<change-name>/.orbit-runs/`.

## Edge cases

### Already archived

If `openspec/changes/archive/<YYYY-MM-DD>-<change-name>/` already exists when the user invokes `/opsx:archive <change-name>` (i.e., a same-day prior archive for the same change name):

Halt with a clear error:

```
Change <name> is already at openspec/changes/archive/<YYYY-MM-DD>-<name>/.
```

Do NOT prompt to overwrite; the user must explicitly resolve the conflict (rename existing archive, use different date, etc.).

### audit-drift fails to run

Already covered in Step 3.5 — proceed with warning; summary records `audit.ran: false` + failure reason. Do NOT block on audit-tool failures.

## Audit is informational, not gate

Audit-drift findings are **informational** unless the user explicitly chooses to abort. The archive command does NOT:

- Attempt to resolve audit findings automatically (user's responsibility via `/opsx:address-reviews` or manual edit).
- Auto-invoke `/opsx:review --as system` even if it hasn't run for this change. System-mode review is the user's gate — their responsibility to run it before archiving if they want that signal.

This is a deliberate choice (per D11 in the bootstrap design): users may legitimately archive with known drift (e.g., follow-up commit planned). orbit captures the decision in the summary for traceability, but doesn't override.
