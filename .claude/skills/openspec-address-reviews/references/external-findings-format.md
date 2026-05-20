# Reference: external-findings file format (for `--from-file` parsing)

The `--from-file <path>` flag ingests an external-AI's findings file. The file is produced by `/opsx:review-external` workflows — typically the external AI writes it after pulling the repo and reading the prompt.

This format MUST match what `/opsx:review-external` instructs the external AI to write. Deviations on either side break the cross-AI loop.

## Expected file format

```markdown
# External Review: <change-name> (iteration <N>)

**Reviewer**: <model name>
**Date**: <YYYY-MM-DD>

## CRITICAL

### <Finding title>
**File**: <path>:<line>
**Description**: <what's wrong + specific recommendation>

## WARNING

### <Finding title>
**File**: <path>:<line>
**Description**: <text>

## SUGGESTION

### <Finding title>
**File**: <path>:<line>
**Description**: <text>

## Notes

<Optional: overall impression, broader concerns.>
```

## Parser contract

For each finding under each severity section, construct a virtual marker with:

| Virtual marker field | Source |
|---|---|
| `severity` | The `## <SEVERITY>` section header (CRITICAL / WARNING / SUGGESTION) |
| `title` | The `### <Finding title>` line |
| `file:line` | The `**File**: <path>:<line>` field |
| `description` | The `**Description**: <text>` field |
| `source` | Always `external` (vs `inline` for grep-found markers) |

Virtual markers walk the same lifecycle as inline markers, with one exception: **the marker-removal step (Step 3d in the SKILL.md walk) is a no-op for virtual markers** — there's no source-file marker text to delete.

## Malformed input handling

If the file is missing required sections, has broken field labels, or otherwise can't be parsed cleanly:

- Report a parse error to the user with the expected format above
- Exit without acting on partial input — do not attempt to walk a half-parsed marker set
- The user fixes the file and re-runs

## Tolerated variations

The parser SHOULD be lenient on:

- Whitespace between sections (blank lines OK)
- `**Reviewer**:` and `**Date**:` field absence (warn, don't fail; reviewer attribution falls back to "unknown external AI")
- Optional `## Notes` section absent (treated as no notes)
- **Empty-severity sentinel**: when a severity section contains the single body line `None.` (or equivalent — `None`, `none.`, `(none)`) with no `### <Title>` entries underneath, the section parses cleanly to zero findings at that severity. This matches what external reviewers naturally write when there are no findings at a given severity.

The parser MUST be strict on:

- Severity section headers (`## CRITICAL`, `## WARNING`, `## SUGGESTION` — exact case)
- Finding titles use `### ` prefix
- `**File**:` and `**Description**:` field labels (exact)

The reason for the strict/lenient split: the strict items are what the orbit format guarantees and what allows cross-AI loops to work; the lenient items vary across reviewers without breaking semantics.

## Quick worked example of valid input

```markdown
# External Review: <change-name> (iteration 1)

**Reviewer**: GPT-5 Codex
**Date**: 2026-05-18

## CRITICAL

None.

## WARNING

### First finding title
**File**: path/to/file.md:42
**Description**: What's wrong + recommendation.

### Second finding title
**File**: another/path.md:88
**Description**: Detail.

## SUGGESTION

### A suggestion
**File**: README.md:909
**Description**: Detail.

## Notes

Overall impression goes here.
```

This example has 0 CRITICAL (using `None.` sentinel), 2 WARNING, 1 SUGGESTION. The codex-pushed iter-1 system-mode findings file (`openspec/changes/bootstrap-openspec-orbit/.orbit-runs/external-system-2026-05-18T17-33-40Z.md`) is a real-world example produced by GPT-5 Codex.
