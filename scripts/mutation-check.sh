#!/usr/bin/env bash
set -euo pipefail

# scripts/mutation-check.sh
# Verifies that every security mutation causes test failures in supabase test db.
# Exit non-zero if any mutation leaves the test suite green.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== DeutschMate Database Mutation Checker ==="

# Check if supabase CLI and Docker are available
if ! command -v supabase &> /dev/null && ! npx supabase --version &> /dev/null; then
  echo "Error: supabase CLI is not installed or available via npx."
  exit 1
fi

SUPABASE_CMD="supabase"
if ! command -v supabase &> /dev/null; then
  SUPABASE_CMD="npx supabase"
fi

# Verify stack is running
if ! $SUPABASE_CMD status &> /dev/null; then
  echo "Local Supabase stack is not running. Please start it with 'supabase start' before running mutation checks."
  exit 1
fi

MIGRATIONS_DIR="$PROJECT_ROOT/supabase/migrations"
BACKUP_DIR="$(mktemp -d)"
trap 'rm -rf "$BACKUP_DIR"' EXIT

# Copy real migrations to backup dir
cp -r "$MIGRATIONS_DIR"/* "$BACKUP_DIR/"

cleanup_and_restore() {
  cp -r "$BACKUP_DIR"/* "$MIGRATIONS_DIR/"
  $SUPABASE_CMD db reset --linked=false
}

trap 'cleanup_and_restore; rm -rf "$BACKUP_DIR"' EXIT

declare -A MUTATIONS=(
  ["mutation_1_grant_insert_created_at"]="sed -i 's/GRANT INSERT (id, event_type/GRANT INSERT (id, created_at, event_type/' supabase/migrations/20261024000002_create_learning_events.sql"
  ["mutation_2_remove_is_active_from_events_insert"]="sed -i '/AND is_active = true/d' supabase/migrations/20261024000002_create_learning_events.sql"
  ["mutation_3_trigger_ignores_client_created_at"]="sed -i 's/v_event_ts := .*/v_event_ts := now();/' supabase/migrations/20261024000002_create_learning_events.sql"
  ["mutation_4_remove_streak_end_date_filter"]="sed -i 's/WHERE end_date IN (v_today, v_yesterday)//' supabase/migrations/20261024000004_create_admin_functions.sql"
  ["mutation_5_remove_least_xp_cap"]="sed -i 's/LEAST(200, SUM(event_xp))/SUM(event_xp)/' supabase/migrations/20261024000004_create_admin_functions.sql"
  ["mutation_6_grant_update_role"]="sed -i 's/GRANT UPDATE (display_name, teaching_language, timezone)/GRANT UPDATE (display_name, teaching_language, timezone, role)/' supabase/migrations/20261024000001_create_profiles.sql"
  ["mutation_7_remove_exercise_incorrect_from_streak"]="sed -i \"s/'exercise_incorrect'//g\" supabase/migrations/20261024000004_create_admin_functions.sql"
)

OVERALL_PASS=true

for MUTATION_NAME in "${!MUTATIONS[@]}"; do
  echo ""
  echo "--- Testing $MUTATION_NAME ---"
  
  # Restore clean migrations
  cp -r "$BACKUP_DIR"/* "$MIGRATIONS_DIR/"
  
  # Apply mutation
  eval "${MUTATIONS[$MUTATION_NAME]}"
  
  # Reset DB with mutated migration
  $SUPABASE_CMD db reset --linked=false > /dev/null
  
  # Run tests and capture output
  TEST_OUTPUT=$($SUPABASE_CMD test db 2>&1 || true)
  
  if echo "$TEST_OUTPUT" | grep -q "All tests successful"; then
    echo "FAIL: $MUTATION_NAME left the test suite completely GREEN! Test suite is missing coverage."
    OVERALL_PASS=false
  else
    FAILED_TESTS=$(echo "$TEST_OUTPUT" | grep "not ok" || true)
    echo "SUCCESS: $MUTATION_NAME was caught by the test suite."
    echo "Failed tests:"
    echo "$FAILED_TESTS"
  fi
done

# Final restore of clean migrations
cleanup_and_restore

if [ "$OVERALL_PASS" = true ]; then
  echo ""
  echo "=== All 7 mutations were properly caught by the test suite! ==="
  exit 0
else
  echo ""
  echo "=== Some mutations were NOT caught! Fix the test suite. ==="
  exit 1
fi
