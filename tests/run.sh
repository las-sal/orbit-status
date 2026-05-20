#!/usr/bin/env bash
# ============================================================================
# tests/run.sh — test runner for opsx-status v0.1
#
# Plain-bash assertions (bats not installed at fixture build time). Sets up
# ephemeral fixture projects under $TMP_BASE, exercises the four capability
# specs' key scenarios, and reports a pass/fail count.
#
# Usage: tests/run.sh [--verbose]
#
# Each section maps to one spec in openspec/changes/bootstrap-orbit-status-cli/
# specs/. Comprehensive scenario-by-scenario coverage is a v2 polish task;
# v0.1 covers the load-bearing paths.
# ============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPSX_STATUS="$PROJECT_ROOT/.claude/skills/openspec-status/bin/opsx-status"
TMP_BASE="$(mktemp -d -t opsx-status-test-XXXXXX)"

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

trap 'rm -rf "$TMP_BASE"' EXIT

PASS=0
FAIL=0
FAILED_NAMES=()

# ----------------------------------------------------------------------------
# Assertion helpers
# ----------------------------------------------------------------------------

pass() {
  PASS=$((PASS + 1))
  echo "  ✓ $1"
}

fail() {
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("$1")
  echo "  ✗ $1"
  echo "    $2"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$label"
  else
    fail "$label" "expected: '$expected' | actual: '$actual'"
  fi
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$label"
  else
    fail "$label" "haystack: '$(echo "$haystack" | head -c 200)' | needle: '$needle'"
  fi
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    pass "$label"
  else
    fail "$label" "haystack should NOT contain '$needle'"
  fi
}

assert_exit_code() {
  local label="$1" expected_code="$2" actual_code="$3"
  if [[ "$expected_code" == "$actual_code" ]]; then
    pass "$label"
  else
    fail "$label" "expected exit $expected_code, got $actual_code"
  fi
}

assert_json_has_key() {
  local label="$1" json="$2" key="$3"
  if echo "$json" | jq -e "has(\"$key\")" >/dev/null 2>&1; then
    pass "$label"
  else
    fail "$label" "JSON missing key: $key"
  fi
}

assert_json_lacks_key() {
  local label="$1" json="$2" key="$3"
  if echo "$json" | jq -e "has(\"$key\")" >/dev/null 2>&1; then
    fail "$label" "JSON has key it shouldn't: $key"
  else
    pass "$label"
  fi
}

# ----------------------------------------------------------------------------
# Fixture builders (ephemeral under $TMP_BASE)
# ----------------------------------------------------------------------------

# An orbit project with no changes (tier-3 empty)
fixture_empty_orbit() {
  local d="$TMP_BASE/empty-orbit"
  mkdir -p "$d/.claude/skills/openspec-review" "$d/openspec/changes" "$d/openspec/explore"
  echo "stub" > "$d/.claude/skills/openspec-review/SKILL.md"
  echo "$d"
}

# A plain-openspec project (no orbit overlay, no .orbit-runs/) with one in-apply change
fixture_plain_openspec() {
  local d="$TMP_BASE/plain-os"
  mkdir -p "$d/openspec/changes/example-change"
  cat > "$d/openspec/changes/example-change/proposal.md" <<'EOF'
## Why
Plain-openspec test fixture.
EOF
  cat > "$d/openspec/changes/example-change/tasks.md" <<'EOF'
- [x] 1.1 First done
- [ ] 1.2 Second pending
EOF
  echo "$d"
}

# An orbit project with one exploration only
fixture_exploring_only() {
  local d="$TMP_BASE/exploring"
  mkdir -p "$d/.claude/skills/openspec-review" "$d/openspec/changes" "$d/openspec/explore/idea1"
  echo "stub" > "$d/.claude/skills/openspec-review/SKILL.md"
  cat > "$d/openspec/explore/idea1/explore.md" <<'EOF'
# Exploration: idea1

## Decisions
- 2026-05-20 — decision one
EOF
  echo "$d"
}

# An orbit project with one in-apply change + a stale review JSON
fixture_mid_apply() {
  local d="$TMP_BASE/mid-apply"
  mkdir -p "$d/.claude/skills/openspec-review"
  mkdir -p "$d/openspec/changes/work/.orbit-runs"
  echo "stub" > "$d/.claude/skills/openspec-review/SKILL.md"
  cat > "$d/openspec/changes/work/proposal.md" <<'EOF'
## Why
mid-apply fixture
EOF
  cat > "$d/openspec/changes/work/tasks.md" <<'EOF'
- [x] 1.1 Done
- [x] 1.2 Also done
- [ ] 1.3 Pending
- [ ] 1.4 Also pending
EOF
  # An older review JSON — older than tasks.md mtime so freshness condition fails
  cat > "$d/openspec/changes/work/.orbit-runs/review-proposal-2024-01-01T00-00-00Z.json" <<'EOF'
{
  "command": "review",
  "timestamp": "2024-01-01T00:00:00Z",
  "change": "work",
  "mode": "proposal",
  "iteration": 1,
  "findings_summary": { "critical": 0, "warning": 2, "suggestion": 1 },
  "next_recommended": "/opsx:apply work (continue applying)",
  "final_assessment": "ok"
}
EOF
  # touch tasks.md to be newer than the JSON
  touch "$d/openspec/changes/work/tasks.md"
  echo "$d"
}

# An orbit project with one archived change (full archive metadata)
fixture_archived() {
  local d="$TMP_BASE/with-archive"
  mkdir -p "$d/.claude/skills/openspec-review"
  mkdir -p "$d/openspec/changes/archive/2026-05-15-old-change/.orbit-runs"
  echo "stub" > "$d/.claude/skills/openspec-review/SKILL.md"
  echo "## Why" > "$d/openspec/changes/archive/2026-05-15-old-change/proposal.md"
  cat > "$d/openspec/changes/archive/2026-05-15-old-change/.orbit-runs/archive-2026-05-15T15-30-00Z.json" <<'EOF'
{
  "command": "archive",
  "timestamp": "2026-05-15T15:30:00Z",
  "change": "old-change"
}
EOF
  echo "$d"
}

# A change with an unresolved @review: marker
fixture_with_marker() {
  local d="$TMP_BASE/with-marker"
  mkdir -p "$d/.claude/skills/openspec-review" "$d/openspec/changes/marked"
  echo "stub" > "$d/.claude/skills/openspec-review/SKILL.md"
  cat > "$d/openspec/changes/marked/proposal.md" <<'EOF'
## Why
fixture with marker
EOF
  cat > "$d/openspec/changes/marked/design.md" <<'EOF'
## Decisions

@review: this thing might be wrong
EOF
  cat > "$d/openspec/changes/marked/tasks.md" <<'EOF'
- [ ] 1.1 Pending
EOF
  echo "$d"
}

# ----------------------------------------------------------------------------
# Test sections
# ----------------------------------------------------------------------------

section() {
  echo ""
  echo "── $1 ──"
}

# ============================================================================
# orbit-status-output spec scenarios
# ============================================================================

test_output_spec() {
  section "orbit-status-output spec"

  # --json has all 6 top-level keys
  local fix
  fix=$(fixture_mid_apply)
  local out
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  for key in project focus active exploring recent totals; do
    assert_json_has_key "--json includes top-level key: $key" "$out" "$key"
  done

  # --limit 0 → empty recent[]
  fix=$(fixture_archived)
  out=$(cd "$fix" && "$OPSX_STATUS" --json --limit 0 2>/dev/null)
  local recent_len
  recent_len=$(echo "$out" | jq '.recent | length')
  assert_eq "--limit 0 yields empty recent[]" "0" "$recent_len"

  # --limit defaults to 5; with 1 archived, recent has 1
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  recent_len=$(echo "$out" | jq '.recent | length')
  assert_eq "--limit default surfaces archived changes" "1" "$recent_len"

  # --limit -1 → non-zero exit + stderr error
  local code
  out=$(cd "$fix" && "$OPSX_STATUS" --limit -1 2>&1)
  code=$?
  assert_exit_code "--limit -1 fails with non-zero" "1" "$code"
  assert_contains "--limit -1 stderr names the invalid arg" "$out" "negative"

  # --change pins focus, sets ranking_basis to user_specified
  fix=$(fixture_mid_apply)
  out=$(cd "$fix" && "$OPSX_STATUS" --json --change work 2>/dev/null)
  local rb
  rb=$(echo "$out" | jq -r '.focus.ranking_basis')
  assert_eq "--change sets ranking_basis to user_specified" "user_specified" "$rb"

  # --change on nonexistent thread → non-zero exit
  out=$(cd "$fix" && "$OPSX_STATUS" --change does-not-exist 2>&1)
  code=$?
  assert_exit_code "--change on missing thread fails" "1" "$code"
  assert_contains "--change error mentions missing name" "$out" "does-not-exist"

  # openspec/ not found → exit 1
  out=$(cd "$TMP_BASE" && "$OPSX_STATUS" 2>&1)
  code=$?
  assert_exit_code "no openspec/ exits non-zero" "1" "$code"
  assert_contains "no openspec/ stderr names the problem" "$out" "openspec"

  # --help has expected flags listed
  out=$("$OPSX_STATUS" --help 2>&1)
  for flag in -- detail json change limit help version; do
    assert_contains "--help mentions: $flag" "$out" "$flag"
  done

  # --version emits VERSION
  out=$("$OPSX_STATUS" --version 2>&1)
  assert_contains "--version output starts with opsx-status" "$out" "opsx-status"

  # W3 regression (external system review iter-1): default human view's
  # primary line includes last-touched relative time. Run against the
  # mid-apply fixture, verify human output contains 'touched'.
  fix=$(fixture_mid_apply)
  out=$(cd "$fix" && "$OPSX_STATUS" 2>/dev/null)
  assert_contains "W3 regression: default human view includes 'touched <rel>' segment" "$out" "touched"
}

# ============================================================================
# orbit-status-phase-model spec scenarios
# ============================================================================

test_phase_model_spec() {
  section "orbit-status-phase-model spec"

  # Rule 3: partial tasks.md → applying
  local fix out phase
  fix=$(fixture_mid_apply)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  phase=$(echo "$out" | jq -r '.active[0].phase')
  assert_eq "partial tasks → applying" "applying" "$phase"

  # Rule 4: proposal.md exists, no tasks completed → proposed
  fix="$TMP_BASE/proposed"
  mkdir -p "$fix/.claude/skills/openspec-review" "$fix/openspec/changes/x"
  echo "stub" > "$fix/.claude/skills/openspec-review/SKILL.md"
  echo "## Why" > "$fix/openspec/changes/x/proposal.md"
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  phase=$(echo "$out" | jq -r '.active[0].phase')
  assert_eq "proposal-only → proposed" "proposed" "$phase"

  # Rule 5: explore-only → exploring
  fix=$(fixture_exploring_only)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  phase=$(echo "$out" | jq -r '.exploring[0].phase')
  assert_eq "explore-only → exploring" "exploring" "$phase"

  # Archived change in recent[] has phase: archived
  fix=$(fixture_archived)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  phase=$(echo "$out" | jq -r '.recent[0].phase')
  assert_eq "archived directory → archived" "archived" "$phase"

  # Phase enum is closed — only valid values appear
  for f in $(fixture_mid_apply) $(fixture_exploring_only) $(fixture_archived); do
    out=$(cd "$f" && "$OPSX_STATUS" --json 2>/dev/null)
    local phases
    phases=$(echo "$out" | jq -r '(.active + .exploring + .recent)[].phase' | sort -u)
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      case "$p" in
        exploring|proposed|applying|reviewing|verified|archived) ;;
        *) fail "phase enum closed in $f" "got invalid phase: $p"; continue 2 ;;
      esac
    done <<< "$phases"
  done
  pass "all emitted phases are in the closed enum (exploring|proposed|applying|reviewing|verified|archived)"

  # Unresolved marker emits attention
  fix=$(fixture_with_marker)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  local marker_count
  marker_count=$(echo "$out" | jq '[.active[0].attention[] | select(.type == "unresolved_marker")] | length')
  if [[ "$marker_count" -ge 1 ]]; then
    pass "unresolved @review: marker emits attention entry"
  else
    fail "unresolved @review: marker emits attention entry" "expected >=1, got $marker_count"
  fi

  # W2 regression (external system review iter-1): phase freshness uses
  # filename-embedded timestamp, NOT filesystem mtime. Set up a fixture
  # where the JSON's FILE mtime is fresh (just touched) but its FILENAME
  # timestamp is ancient (2024). Phase should still be `applying` (rule 3),
  # not `reviewing` (rule 2 should NOT fire because the filename ts is
  # older than tasks.md).
  fix="$TMP_BASE/w2-regression"
  mkdir -p "$fix/.claude/skills/openspec-review" \
    "$fix/openspec/changes/work/.orbit-runs"
  echo "stub" > "$fix/.claude/skills/openspec-review/SKILL.md"
  echo "## Why" > "$fix/openspec/changes/work/proposal.md"
  cat > "$fix/openspec/changes/work/tasks.md" <<'EOF'
- [x] 1.1 Done
- [ ] 1.2 Pending
EOF
  cat > "$fix/openspec/changes/work/.orbit-runs/review-system-2024-01-01T00-00-00Z.json" <<'EOF'
{"command":"review","timestamp":"2024-01-01T00:00:00Z","mode":"system","next_recommended":"/opsx:archive work"}
EOF
  # Touch the review JSON's mtime to NOW (simulating clone/cp/touch corruption)
  touch "$fix/openspec/changes/work/.orbit-runs/review-system-2024-01-01T00-00-00Z.json"
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  phase=$(echo "$out" | jq -r '.active[0].phase')
  assert_eq "W2 regression: fresh fs-mtime + old filename-ts → applying (rule 2 must NOT fire on mtime alone)" "applying" "$phase"
}

# ============================================================================
# orbit-status-recommendation spec scenarios
# ============================================================================

test_recommendation_spec() {
  section "orbit-status-recommendation spec"

  # Tier-3 fallback on empty orbit project
  local fix out cmd
  fix=$(fixture_empty_orbit)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  cmd=$(echo "$out" | jq -r '.focus.recommended_next.command')
  assert_eq "tier-3: empty project → /opsx:explore" "/opsx:explore" "$cmd"
  assert_contains "tier-3: reason names 'No active workflow'" "$out" "No active workflow"

  # Tier-2 rule 1: only explore.md → /opsx:propose
  fix=$(fixture_exploring_only)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  cmd=$(echo "$out" | jq -r '.focus.recommended_next.command')
  assert_eq "tier-2 rule 1: explore-only → /opsx:propose" "/opsx:propose" "$cmd"

  # Tier-2 rule 4: partial tasks.md → /opsx:apply (review JSON exists but is OLDER than tasks)
  fix=$(fixture_mid_apply)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  cmd=$(echo "$out" | jq -r '.focus.recommended_next.command')
  assert_eq "tier-2 rule 4: partial tasks → /opsx:apply" "/opsx:apply" "$cmd"

  # Marker override: tier-1 override fires when markers exist
  fix=$(fixture_with_marker)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  cmd=$(echo "$out" | jq -r '.focus.recommended_next.command')
  assert_eq "marker override → /opsx:address-reviews" "/opsx:address-reviews" "$cmd"

  # Focus block fully populated for active project
  fix=$(fixture_mid_apply)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  for field in summary primary_change primary_change_kind ranking_basis recommended_next secondary_threads; do
    assert_json_has_key "focus block populated: $field" "$(echo "$out" | jq -c '.focus')" "$field"
  done

  # Focus block minimal for empty project (no primary_change / ranking_basis)
  fix=$(fixture_empty_orbit)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  assert_json_lacks_key "tier-3 focus omits primary_change" "$(echo "$out" | jq -c '.focus')" "primary_change"

  # W1 regression (external system review iter-1): list_orbit_runs sorts by
  # embedded timestamp, NOT by full filename. Set up a fixture with two
  # JSONs where the alphabetically-later prefix has the older timestamp.
  # Tier-1 should source from the timestamp-newer JSON.
  fix="$TMP_BASE/w1-regression"
  mkdir -p "$fix/.claude/skills/openspec-review" \
    "$fix/openspec/changes/work/.orbit-runs"
  echo "stub" > "$fix/.claude/skills/openspec-review/SKILL.md"
  echo "## Why" > "$fix/openspec/changes/work/proposal.md"
  cat > "$fix/openspec/changes/work/tasks.md" <<'EOF'
- [x] 1.1 Done
- [ ] 1.2 Pending
EOF
  # Older timestamp, alphabetically later prefix (review-system > address-reviews)
  cat > "$fix/openspec/changes/work/.orbit-runs/review-system-2026-05-20T09-00-00Z.json" <<'EOF'
{"command":"review","timestamp":"2026-05-20T09:00:00Z","mode":"system","next_recommended":"OLDER — should NOT win"}
EOF
  # Newer timestamp, alphabetically earlier prefix
  cat > "$fix/openspec/changes/work/.orbit-runs/address-reviews-2026-05-20T10-00-00Z.json" <<'EOF'
{"command":"address-reviews","timestamp":"2026-05-20T10:00:00Z","next_recommended":"NEWER — SHOULD win","resolution_summary":{"resolved":0}}
EOF
  # Force the JSON mtimes to be NOW so phase rule 2 won't fire (newer than tasks.md)
  # — we want to verify tier-1 picks the correct latest. Use --json output.
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  reason=$(echo "$out" | jq -r '.focus.recommended_next.reason')
  assert_contains "W1 regression: latest_orbit_run sorts by embedded ts (newer wins despite later-alphabetical-prefix older sibling)" "$reason" "NEWER"
}

# ============================================================================
# orbit-status-distribution spec scenarios
# ============================================================================

test_distribution_spec() {
  section "orbit-status-distribution spec"

  # Binary present + executable
  if [[ -x "$OPSX_STATUS" ]]; then
    pass "binary present + executable at .claude/skills/openspec-status/bin/opsx-status"
  else
    fail "binary present + executable" "not executable: $OPSX_STATUS"
  fi

  # is_orbit_project: true when overlay marker exists
  local fix out is_orbit
  fix=$(fixture_empty_orbit)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  is_orbit=$(echo "$out" | jq -r '.project.is_orbit_project')
  assert_eq "overlay marker → is_orbit_project: true" "true" "$is_orbit"

  # is_orbit_project: false on plain-openspec
  fix=$(fixture_plain_openspec)
  out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)
  is_orbit=$(echo "$out" | jq -r '.project.is_orbit_project')
  assert_eq "no overlay, no .orbit-runs → is_orbit_project: false" "false" "$is_orbit"

  # Plain-openspec: review_history omitted
  assert_json_lacks_key "plain-openspec omits review_history" "$(echo "$out" | jq -c '.active[0]')" "review_history"

  # Plain-openspec --detail: source omitted from recommended_next
  out=$(cd "$fix" && "$OPSX_STATUS" --json --detail 2>/dev/null)
  assert_json_lacks_key "plain-openspec --detail omits source field" "$(echo "$out" | jq -c '.focus.recommended_next')" "source"

  # Plain-openspec human view: no "(orbit project)" tag
  out=$(cd "$fix" && "$OPSX_STATUS" 2>/dev/null)
  assert_not_contains "plain-openspec human view drops '(orbit project)' tag" "$out" "(orbit project)"

  # Plain-openspec still emits unresolved_marker (verify with a marker fixture)
  local marker_fix="$TMP_BASE/plain-with-marker"
  mkdir -p "$marker_fix/openspec/changes/m"
  echo "## Why" > "$marker_fix/openspec/changes/m/proposal.md"
  cat > "$marker_fix/openspec/changes/m/design.md" <<'EOF'
@review: something
EOF
  out=$(cd "$marker_fix" && "$OPSX_STATUS" --json 2>/dev/null)
  local m_count
  m_count=$(echo "$out" | jq '[.active[0].attention[] | select(.type == "unresolved_marker")] | length')
  if [[ "$m_count" -ge 1 ]]; then
    pass "plain-openspec still emits unresolved_marker attention"
  else
    fail "plain-openspec still emits unresolved_marker attention" "got $m_count entries"
  fi

  # All four surfaces present in the overlay (orbit project on disk)
  for path in \
    "$PROJECT_ROOT/.claude/skills/openspec-status/SKILL.md" \
    "$PROJECT_ROOT/.claude/commands/opsx/status.md" \
    "$PROJECT_ROOT/.claude/skills/openspec-status/bin/opsx-status"; do
    if [[ -e "$path" ]]; then
      pass "surface present: ${path#$PROJECT_ROOT/}"
    else
      fail "surface present: ${path#$PROJECT_ROOT/}" "missing"
    fi
  done
}

# ============================================================================
# Schema validation — --json output validates against the documented shape
# ============================================================================

test_schema_validation() {
  section "schema validation (--json shape across all fixtures)"

  for fix in $(fixture_empty_orbit) $(fixture_plain_openspec) $(fixture_exploring_only) $(fixture_mid_apply) $(fixture_archived) $(fixture_with_marker); do
    local name
    name=$(basename "$fix")
    local out
    out=$(cd "$fix" && "$OPSX_STATUS" --json 2>/dev/null)

    # All 6 top-level keys present
    local all_present=true
    for key in project focus active exploring recent totals; do
      if ! echo "$out" | jq -e "has(\"$key\")" >/dev/null 2>&1; then
        all_present=false
        fail "schema [$name]: top-level keys" "missing $key"
        break
      fi
    done
    $all_present && pass "schema [$name]: all 6 top-level keys"

    # active, exploring, recent are arrays
    for key in active exploring recent; do
      local t
      t=$(echo "$out" | jq -r ".$key | type")
      assert_eq "schema [$name]: $key is array" "array" "$t"
    done

    # totals has numeric subkeys
    for tkey in active exploring archived; do
      local v
      v=$(echo "$out" | jq -r ".totals.$tkey | type")
      assert_eq "schema [$name]: totals.$tkey is number" "number" "$v"
    done
  done
}

# ----------------------------------------------------------------------------
# Run
# ----------------------------------------------------------------------------

echo "opsx-status v0.1 test suite"
echo "binary: $OPSX_STATUS"
echo "tmp:    $TMP_BASE"

test_output_spec
test_phase_model_spec
test_recommendation_spec
test_distribution_spec
test_schema_validation

echo ""
echo "======================================"
echo "Results: $PASS passed, $FAIL failed"
echo "======================================"

if (( FAIL > 0 )); then
  echo ""
  echo "Failed tests:"
  for n in "${FAILED_NAMES[@]}"; do
    echo "  - $n"
  done
  exit 1
fi
