---
name: openspec-propose
description: "Propose a new change with all artifacts generated in one step. Use when the user wants to quickly describe what they want to build and get a complete proposal with design, specs, and tasks ready for implementation."
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.3.1"
---
Propose a new change - create the change and generate all artifacts in one step.

I'll create a change with artifacts:
- proposal.md (what & why)
- design.md (how)
- tasks.md (implementation steps)

When ready to implement, run /opsx:apply

---

**Input**: The user's request should include a change name (kebab-case) OR a description of what they want to build.

**Steps**

1. **If no clear input provided, ask what they want to build**

   Use the **AskUserQuestion tool** (open-ended, no preset options) to ask:
   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" → `add-user-auth`).

   **IMPORTANT**: Do NOT proceed without understanding what the user wants to build.

2. **Create the change directory**
   ```bash
   openspec new change "<name>"
   ```
   This creates a scaffolded change at `openspec/changes/<name>/` with `.openspec.yaml`.

3. **Get the artifact build order**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to get:
   - `applyRequires`: array of artifact IDs needed before implementation (e.g., `["tasks"]`)
   - `artifacts`: list of all artifacts with their status and dependencies

4. **Create artifacts in sequence until apply-ready**

   Use the **TodoWrite tool** to track progress through the artifacts.

   Loop through artifacts in dependency order (artifacts with no pending dependencies first):

   a. **For each artifact that is `ready` (dependencies satisfied)**:
      - Get instructions:
        ```bash
        openspec instructions <artifact-id> --change "<name>" --json
        ```
      - The instructions JSON includes:
        - `context`: Project background (constraints for you - do NOT include in output)
        - `rules`: Artifact-specific rules (constraints for you - do NOT include in output)
        - `template`: The structure to use for your output file
        - `instruction`: Schema-specific guidance for this artifact type
        - `outputPath`: Where to write the artifact
        - `dependencies`: Completed artifacts to read for context
      - Read any completed dependency files for context
      - Create the artifact file using `template` as the structure
      - Apply `context` and `rules` as constraints - but do NOT copy them into the file
      - Show brief progress: "Created <artifact-id>"

   b. **Continue until all `applyRequires` artifacts are complete**
      - After creating each artifact, re-run `openspec status --change "<name>" --json`
      - Check if every artifact ID in `applyRequires` has `status: "done"` in the artifacts array
      - Stop when all `applyRequires` artifacts are done

   c. **If an artifact requires user input** (unclear context):
      - Use **AskUserQuestion tool** to clarify
      - Then continue with creation

5. **Show final status**
   ```bash
   openspec status --change "<name>"
   ```

**Output**

After completing all artifacts, summarize:
- Change name and location
- List of artifacts created with brief descriptions
- What's ready: "All artifacts created! Ready for implementation."
- Prompt: "Run `/opsx:apply` or ask me to implement to start working on the tasks."

**Artifact Creation Guidelines**

- Follow the `instruction` field from `openspec instructions` for each artifact type
- The schema defines what each artifact should contain - follow it
- Read dependency artifacts for context before creating new ones
- Use `template` as the structure for your output file - fill in its sections
- **IMPORTANT**: `context` and `rules` are constraints for YOU, not content for the file
  - Do NOT copy `<context>`, `<rules>`, `<project_context>` blocks into the artifact
  - These guide what you write, but should never appear in the output

**Guardrails**
- Create ALL artifacts needed for implementation (as defined by schema's `apply.requires`)
- Always read dependency artifacts before creating a new one
- If context is critically unclear, ask the user - but prefer making reasonable decisions to keep momentum
- If a change with that name already exists, ask if user wants to continue it or create a new one
- Verify each artifact file exists after writing before proceeding to next

---

# Orbit additions

The sections below describe orbit-specific additions on top of upstream's standalone propose flow. The upstream content above is unchanged. Orbit adds a **consume mode** that activates when `openspec/explore/<name>/explore.md` exists from a prior `/opsx:explore` session — the exploration becomes the authoritative seed for artifact generation rather than asking the user for a description.

## Three execution disciplines (apply throughout this command)

**Read-before-reference (authoring-time)**. When generating artifacts (proposal/design/specs/tasks) that reference specific constructs in the codebase, read the actual definitions first. Don't infer function signatures, file paths, or capability names from training-data patterns. The artifacts you generate become the normative contract; false-precision references corrupt that contract.

**Change completeness (modification-time)**. In consume mode, the section-mapping from `explore.md` → generated artifacts is a substantive modification. Apply it fully: if a Decision informs both a spec requirement AND a design entry AND a task, write all three. If an Open question becomes a `@review:` marker, insert it in the relevant artifact (don't just note it in explore.md and forget the marker). After artifact generation but before the staging-directory move, sweep for incomplete propagation.

**Pushback (review-time)**. When mid-generation the user pushes back on something (e.g., "that decision actually changed in the last conversation"), verify against current state of `explore.md` and the conversation before re-editing. If the explore.md content is current, ask the user whether to update it or to override for this generation. Don't silently diverge from the captured exploration.

## Mode detection (NEW Step 0 — runs before upstream Step 1)

Before any upstream step, detect whether to run in consume mode or fall through to upstream standalone behavior:

1. **Check for staging directory**: does `openspec/explore/<name>/explore.md` exist?
   - **If user provided `<name>`** as the argument: check that specific name.
   - **If user provided no name** but exactly one staging directory exists under `openspec/explore/`: propose that name to the user via `AskUserQuestion`. On accept, treat as if the name was provided.
   - **If user provided no name and zero or multiple staging directories exist**: prompt user to specify a name (zero) or pick one (multiple).

2. **Check for conflict**: do both `openspec/explore/<name>/` AND `openspec/changes/<name>/` exist?
   - If yes, halt with a conflict report and prompt via `AskUserQuestion`:
     - **Regenerate from explore** — overwrite the existing change directory with new artifacts.
     - **Continue from change** — discard the explore staging directory, proceed in standalone-like mode on the existing change.
     - **Abort** — do nothing; user decides next.

3. **Resolve mode**:
   - Staging exists, no conflict → **consume mode** (continue with consume-mode flow below; skip upstream Step 1).
   - No staging → **standalone mode** (skip the consume-mode flow; resume at upstream Step 1).

## Consume-mode flow

Replaces upstream Step 1 (the "ask what to build" prompt). All later upstream steps (create change directory, generate artifacts in dependency order) still run, but they read the exploration material rather than prompting the user.

### Step 0a — Validate `explore.md` structure

Read `openspec/explore/<name>/explore.md`. Check for the five-section structure (Premise / Decisions / Open questions / Considered & out / References).

- **All five sections present** → proceed normally.
- **Missing one or more sections** → warn the user about the missing sections; prompt via `AskUserQuestion` to confirm proceed-anyway (default: proceed).
- **Cannot read or parse** → halt with a clear error; user fixes and re-invokes.

### Step 0b — Handle Open questions

For each entry in the Open questions section, prompt the user via `AskUserQuestion` with three options:

- **Resolve now** — user provides a resolution. The resolution becomes a Decision: appended to the Decisions section of `explore.md` (the file is updated, not just the in-memory parse), and used to inform generated artifacts.
- **Defer as `@review:` marker** — a `@review: <question text>` marker is inserted at the most relevant location in the generated artifacts (typically `design.md` or the relevant spec). The Open question is moved to a "Deferred to markers" subsection of Open questions in `explore.md` (or tagged `deferred`).
- **Abandon** — the question is moved to Considered & out with a brief rationale; no marker is created.

**Bulk handling**: if more than ~5 Open questions exist, offer "Resolve all (walk one by one)" / "Defer all (mark in artifacts)" / "Abandon all" / "Walk each individually" via `AskUserQuestion`. Default: walk each individually.

### Step 0c — Section-to-artifact mapping

When generating artifacts in upstream Step 4, apply this mapping:

| `explore.md` section | Feeds into |
|---|---|
| **Premise** | `proposal.md`'s "Why" / motivation section |
| **Decisions** | Spec requirements + `design.md` decisions + `tasks.md` task seeds. **Preserve specific decision wording** where artifact format permits; don't paraphrase. |
| **Open questions** (resolved at Step 0b) | Promoted to Decisions and treated as above |
| **Open questions** (deferred at Step 0b) | `@review:` markers in `design.md` or the relevant spec |
| **Considered & out** | `design.md`'s "Alternatives considered" section (prevents future rediscovery) |
| **References** | Read during artifact generation as context; cited in `design.md` where relevant; not copied verbatim |

When `design.md` references background or decisions originally from `explore.md`, **cite the source** (`see explore.md`) rather than paraphrasing without attribution.

### Step 0d — Move the staging directory

After all upstream steps complete successfully (artifacts generated, validation passes):

```bash
mv openspec/explore/<name>/* openspec/changes/<name>/
rmdir openspec/explore/<name>
```

(Or equivalent — preserve `explore.md` AND any sibling files like `sketches/` AND any draft convention files. The staging directory should no longer exist; its contents land alongside the generated artifacts in the change directory.)

After the move, `openspec/changes/<name>/` contains both:
- The moved exploration files (`explore.md`, `sketches/`, draft conventions)
- The generated artifacts (`proposal.md`, `design.md`, `specs/`, `tasks.md`)

`explore.md` persists unchanged as the historical record of how the change took shape.

## Standalone mode (unchanged from upstream)

When no `openspec/explore/<name>/` exists, fall through to upstream Step 1: prompt for description, generate artifacts from the description. This mode is fully unchanged from upstream behavior.

## Graceful degradation

- **`explore.md` missing one or more sections** → warn, proceed-anyway by default; missing sections don't have a feeding role in generation.
- **`explore.md` has no Decisions** → the generated artifacts proceed but flag that they're being generated from Premise + Open questions alone, which usually means the exploration wasn't ready for promotion. Suggest user run more `/opsx:explore` work before applying.
- **`openspec/changes/<name>/` already exists in conflict** → three-way prompt (regenerate / continue / abort) is mandatory; do not silently overwrite.
- **No staging directory but user explicitly invoked propose** → standalone mode, no message.
