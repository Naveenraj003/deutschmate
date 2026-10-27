# DeutschMate

Bilingual German learning platform for English and Tamil speakers.

## Tech Stack
- **Frontend**: React, Vite, TypeScript, Tailwind CSS v4 (`@tailwindcss/vite`), React Router v7, `vite-plugin-pwa`
- **Backend & Auth**: Supabase Auth and PostgreSQL with Row Level Security (RLS)

---

## Initial Setup & Development

```bash
# Install dependencies
npm install

# Run local development server
npm run dev

# Run type check and production build
npm run build

# Preview production build locally
npm run preview
```

---

## Database Architecture & Supabase Migrations

Reviewable migrations reside under `supabase/migrations/`:
1. `20261024000001_create_profiles.sql`: Profiles table, `local_reward_date(ts, tz)` (SECURITY INVOKER, STABLE), timezone validation trigger (`pg_catalog.pg_timezone_names`), column privileges, self-SELECT without `is_active` requirement, and signup trigger.
2. `20261024000002_create_learning_events.sql`: Append-only telemetry with `reward_date NOT NULL`, BEFORE INSERT trigger clamping `client_created_at` within 48h, resolving user timezone without UTC fallback, column-level INSERT grants, split exercise_id constraints, and stable unique index `idx_events_exercise_daily`.
3. `20261024000003_create_feedback.sql`: Bug reports, content corrections, and suggestions with server-defaulted status and restricted column-level INSERT grants.
4. `20261024000004_create_admin_functions.sql`: `admin_set_user_active`, `admin_set_feedback_status`, and `get_admin_learner_summary` calculating 200 XP/day cap and consecutive streaks using `(reward_date - row_number)` with `local_reward_date`.

---

## Sync Client Contract: Idempotency, 48h Time Clamping & Error Handling

When the offline or sync client submits learning events to Supabase:

1. **Submission Strategy**:
   The client generates a client-side UUID for each event (`id`) and sends an insert with `on_conflict=id` and `ignore-duplicates` (PostgREST upsert with `resolution=ignore-duplicates` or `ON CONFLICT (id) DO NOTHING`).
   - Retried events with the same client UUID are **silently accepted** without duplicate processing or errors.

2. **Handling Unique Constraint Violation (`23505`)**:
   If the database returns SQLSTATE `23505` (Unique Violation), the client inspects the error payload / constraint name:
   - **`learning_events_pkey`**: Event already received and recorded by the server. **Drop event from the offline sync queue**.
   - **`idx_events_exercise_daily`**: The user has already earned XP for this specific `exercise_id` on this `reward_date`. No further XP will be awarded today for this exercise. **Drop event from the offline sync queue**.
   - **Any other constraint / error**: Network error, schema mismatch, or temporary condition. **Keep event in the sync queue and retry later**.

3. **Bounded Client Time: 48-Hour Clamp & Streak Rescues**:
   - The database server authoritatively evaluates `client_created_at` in `set_learning_event_server_fields()`:
     ```sql
     v_event_ts := LEAST(now(), GREATEST(COALESCE(NEW.client_created_at, now()), now() - interval '48 hours'));
     NEW.created_at := now();
     NEW.reward_date := public.local_reward_date(v_event_ts, tz);
     ```
   - **Authoritative server timestamp**: `created_at` is always set to the server's current time (`now()`).
   - **Bounded reward date**: `reward_date` can be up to 48 hours earlier than `created_at`.
   - **Streak rescue within window**: If a learner completed an exercise offline up to 48 hours ago (e.g., yesterday or late last night), the event's `reward_date` is assigned to that earlier calendar day, allowing offline sync to rescue a streak day without permitting arbitrary historical backdating.
   - Future timestamps are clamped to `now()`.
   - Stale offline events older than 48 hours are clamped to `now() - interval '48 hours'`.
   - If `client_created_at` is NULL, it falls back to `now()`.
   - Missing profile lookup raises SQLSTATE `P0002` (no UTC fallback).

4. **Timezone Changes & Streak Impact**:
   - The frontend automatically detects the browser's IANA timezone (e.g., via `Intl.DateTimeFormat().resolvedOptions().timeZone`) and updates `profiles.timezone` on login if different.
   - Historical events store immutable `reward_date` values recorded at insertion time. A subsequent timezone change only shifts future daily boundaries; it never mutates historical reward dates.

---

## Trusted Procedure: Promoting the First Admin

There is **no client-side role switcher or admin signup option** in production. All users signing up via Supabase Auth are assigned `role = 'learner'` and `is_active = true` by the database trigger, ignoring any client metadata.

To promote the initial trusted administrator:

1. Have the administrator sign up normally via the app or create the user in the Supabase Auth dashboard.
2. Retrieve their authenticated user UUID from `auth.users` or the Supabase Auth dashboard:
   ```sql
   SELECT id, email, created_at FROM auth.users WHERE email = 'admin@yourdomain.com';
   ```
3. Execute the following SQL statement directly in the **Supabase Dashboard SQL Editor** (which runs with superuser / service-role privileges):
   ```sql
   -- Replace with the exact authenticated user UUID
   UPDATE public.profiles
   SET role = 'admin'
   WHERE id = 'PASTE-USER-UUID-HERE'
     AND role = 'learner';
   ```
4. Verify the role change:
   ```sql
   SELECT id, display_name, role, is_active FROM public.profiles WHERE id = 'PASTE-USER-UUID-HERE';
   ```

---

## Running Database Tests (pgTAP) & CI

A test suite verifying RLS boundaries, column update rejections, idempotency, streak cases, and admin RPC security is located at `supabase/tests/security_and_rls_test.sql` (67 tests).

### GitHub Actions CI
Automated testing is configured in `.github/workflows/db-tests.yml` using `supabase/setup-cli@v1` and `supabase test db`.

### Local Execution
```bash
# Requires Docker running locally
npx supabase test db --local
```
> **Local Environment Status**: If Docker Desktop is not running, `npx supabase test db --local` cannot connect (`ECONNREFUSED 127.0.0.1:54322`). In this case, tests are marked **UNEXECUTED** until Docker is available.
