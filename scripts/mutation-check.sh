#!/usr/bin/env bash
set -euo pipefail

# scripts/mutation-check.sh
# Applies an exact single-anchor patch to migrations in CI,
# runs supabase db reset and supabase test db, and verifies that the targeted
# assertion fails. Exits with non-zero on SURVIVED or ERROR.

if [ "${CI:-false}" != "true" ]; then
  echo "Error: mutation-check.sh should only be run in CI (CI=true)." >&2
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Exact single-occurrence anchor replacer (pure python, standard library)
apply_exact_anchor_patch() {
  local target_file="$1"
  local anchor="$2"
  local replacement="$3"

  python3 -c "
import sys

path, anchor, replacement = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

count = content.count(anchor)
if count != 1:
    sys.stderr.write(f'Patch Error: anchor string found {count} times (expected exactly 1) in {path}\n')
    sys.exit(1)

new_content = content.replace(anchor, replacement, 1)
with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)
" "$target_file" "$anchor" "$replacement"
}

# Mutation Registry: id | file | anchor | replacement | expected_tag
run_mutation() {
  local m_id="$1"
  local file=""
  local anchor=""
  local replacement=""
  local expected_tag=""

  case "$m_id" in
    "mutation_1_grant_insert_created_at")
      file="supabase/migrations/20261024000002_create_learning_events.sql"
      anchor="GRANT INSERT (id, event_type, lesson_id, exercise_id, word_id, payload, client_created_at)"
      replacement="GRANT INSERT (id, created_at, event_type, lesson_id, exercise_id, word_id, payload, client_created_at)"
      expected_tag="[events-forged-created-at]"
      ;;
    "mutation_2_remove_is_active_from_events_insert")
      file="supabase/migrations/20261024000002_create_learning_events.sql"
      anchor="CREATE POLICY \"learning_events_insert_own\"
  ON public.learning_events
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = (SELECT auth.uid()) AND is_active = true
    )
  );"
      replacement="CREATE POLICY \"learning_events_insert_own\"
  ON public.learning_events
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = (SELECT auth.uid())
    )
  );"
      expected_tag="[events-inactive-learner-insert]"
      ;;
    "mutation_3_trigger_ignores_client_created_at")
      file="supabase/migrations/20261024000002_create_learning_events.sql"
      anchor="v_event_ts := LEAST(now(), GREATEST(COALESCE(NEW.client_created_at, now()), now() - interval '48 hours'));"
      replacement="v_event_ts := now();"
      expected_tag="[events-client-created-at-in-window]"
      ;;
    "mutation_4_remove_streak_end_date_filter")
      file="supabase/migrations/20261024000004_create_admin_functions.sql"
      anchor="WHERE end_date IN (v_today, v_yesterday)"
      replacement="WHERE 1=1"
      expected_tag="[streak-case-d-stale]"
      ;;
    "mutation_5_remove_least_xp_cap")
      file="supabase/migrations/20261024000004_create_admin_functions.sql"
      anchor="LEAST(200, SUM(event_xp)) AS day_xp"
      replacement="SUM(event_xp) AS day_xp"
      expected_tag="[xp-cap-daily-200]"
      ;;
    "mutation_6_grant_update_role")
      file="supabase/migrations/20261024000001_create_profiles.sql"
      anchor="GRANT UPDATE (display_name, teaching_language, timezone) ON TABLE public.profiles TO authenticated;"
      replacement="GRANT UPDATE (display_name, teaching_language, timezone, role) ON TABLE public.profiles TO authenticated;"
      expected_tag="[profiles-update-role-forbidden]"
      ;;
    "mutation_7_remove_exercise_incorrect_from_streak")
      file="supabase/migrations/20261024000004_create_admin_functions.sql"
      anchor="AND event_type IN ('lesson_completed', 'exercise_correct', 'review_correct', 'exercise_incorrect')"
      replacement="AND event_type IN ('lesson_completed', 'exercise_correct', 'review_correct')"
      expected_tag="[streak-case-e-incorrect-only]"
      ;;
    *)
      echo "Unknown mutation id: $m_id"
      exit 1
      ;;
  esac

  echo "=================================================="
  echo "Executing Mutation: $m_id"
  echo "Target File: $file"
  echo "Expected Failing Tag: $expected_tag"
  echo "=================================================="

  # Apply exact anchor patch to migrations
  if ! apply_exact_anchor_patch "$file" "$anchor" "$replacement"; then
    echo "CLASSIFICATION: ERROR (Patch replacement failed)"
    exit 1
  fi

  # Reset DB with mutated schema
  if ! supabase db reset; then
    echo "CLASSIFICATION: ERROR (supabase db reset failed on mutated migration)"
    exit 1
  fi

  # Run pgTAP tests
  set +e
  local test_output
  test_output="$(supabase test db 2>&1)"
  local test_exit_code=$?
  set -e

  echo "--- Raw pg_prove Output ---"
  echo "$test_output"
  echo "---------------------------"

  if [ $test_exit_code -eq 0 ]; then
    echo "CLASSIFICATION: SURVIVED (Test suite unexpectedly PASSED on mutated schema)"
    exit 1
  fi

  if ! echo "$test_output" | grep -F -q "Result: FAIL"; then
    echo "CLASSIFICATION: ERROR (Test run failed but did not produce 'Result: FAIL')"
    exit 1
  fi

  # Match the tag only on failure lines (lines starting "not ok" or containing "Failed test")
  local failure_lines
  failure_lines="$(echo "$test_output" | grep -E '^not ok|Failed test' || true)"

  # Print every failing tag
  echo "Failing tags detected in test run:"
  echo "$failure_lines" | grep -o '\[[^]]*\]' | sort -u || true

  if echo "$failure_lines" | grep -F -q "$expected_tag"; then
    echo "CLASSIFICATION: DETECTED"
    echo "Expected tag $expected_tag was found in failure lines."
    exit 0
  else
    echo "CLASSIFICATION: ERROR (Expected tag '$expected_tag' was NOT found among failure lines)"
    exit 1
  fi
}

if [ $# -eq 0 ]; then
  echo "Usage: scripts/mutation-check.sh <mutation_id>"
  echo "Available mutations:"
  echo "  - mutation_1_grant_insert_created_at"
  echo "  - mutation_2_remove_is_active_from_events_insert"
  echo "  - mutation_3_trigger_ignores_client_created_at"
  echo "  - mutation_4_remove_streak_end_date_filter"
  echo "  - mutation_5_remove_least_xp_cap"
  echo "  - mutation_6_grant_update_role"
  echo "  - mutation_7_remove_exercise_incorrect_from_streak"
  exit 1
fi

run_mutation "$1"
