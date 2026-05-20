# Reference: review run-summary schema

Each `/opsx:review` invocation persists a JSON summary to `openspec/changes/<change-name>/.orbit-runs/review-<mode>-<TS>.json` where `<TS>` is ISO-8601 with hyphens (e.g., `review-proposal-2026-05-18T14-35-23Z.json`).

Create `.orbit-runs/` if it doesn't exist. The file is **committed** (not gitignored) so iteration history travels with the change into archive.

## Schema

```json
{
  "command": "review",
  "timestamp": "<ISO-8601>",
  "change": "<change-name>",
  "mode": "proposal" | "system",
  "iteration": <integer, per-mode>,
  "depth": "fast" | "full" | "thorough",
  "flags": {
    "parallel": false,
    "focus": null,
    "strict": false,
    "fresh": false,
    "mark": false,
    "skip_verify": false
  },
  "passes_run": ["1", "2", ...],
  "passes_skipped": [],
  "findings_summary": {
    "critical": 0,
    "warning": 0,
    "suggestion": 0,
    "by_pass": {
      "1": { "critical": 0, "warning": 0, "suggestion": 0 },
      "2": { "critical": 0, "warning": 0, "suggestion": 0 }
    }
  },
  "findings": [
    {
      "pass": "1",
      "severity": "CRITICAL" | "WARNING" | "SUGGESTION",
      "file": "design.md",
      "line": 159,
      "title": "<finding title>",
      "recommendation": "<actionable recommendation>"
    }
  ],
  "stale_suppressed": [
    {
      "pass": "<pass id>",
      "title": "<original finding title>",
      "evidence": "<grep output or commit hash showing why it's stale>"
    }
  ],
  "final_assessment": "<stock phrasing from final-assessment table>",
  "iteration_note": "<one-sentence note or null>"
}
```

## Field notes

- **`iteration`** is per-mode: proposal-mode and system-mode iterations count separately on the same change.
- **`passes_run` / `passes_skipped`** are strings (pass IDs); skip reasons go in the report body but not the summary array.
- **`findings_summary.by_pass`** mirrors the report's per-pass grouping for quick downstream parsing.
- **`stale_suppressed`** captures findings that pushback removed; they don't appear in the user-facing report but do persist here for audit.
- **`final_assessment`** is one of the stock phrasings (mode-specific gate text); see the final-assessment table in SKILL.md.
- **`iteration_note`** is the one-line "Note: N of these findings appeared in the last run" comparison; `null` when this is the first run for the mode.
