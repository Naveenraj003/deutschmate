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
1. `20261024000001_create_profiles.sql`: Profiles table, signup trigger, RLS policies, and column-level privileges.
2. `20261024000002_create_learning_events.sql`: Append-only learning telemetry, idempotency keys, and daily unique exercise indexes.
3. `20261024000003_create_feedback.sql`: Bug reports, content corrections, and suggestions.
4. `20261024000004_create_admin_functions.sql`: `admin_set_user_active`, `admin_set_feedback_status`, and `get_admin_learner_summary`.

> **Note on Migration Execution**: In strict review mode, migrations must NOT be applied to any remote database automatically. Always review and apply via approved migration tooling in local staging first.

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

## Running Database Tests (pgTAP)

A test suite verifying RLS boundaries, column update rejections, idempotency, and admin RPC security is located at `supabase/tests/security_and_rls_test.sql`.

To run tests in a local Supabase test container (with `pgtap` extension):
```bash
# Run using local Supabase CLI (never against remote/production)
supabase test db --local
```
Or execute `supabase/tests/security_and_rls_test.sql` inside a test PostgreSQL instance that has `auth.users` mock tables and `pgtap` installed.
