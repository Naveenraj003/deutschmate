-- Supabase pgTAP / SQL Test Suite: DeutschMate Database Security & RLS Verification
-- Execute in a local test environment with pgTAP enabled.
-- DO NOT RUN ON PRODUCTION.

BEGIN;
SELECT plan(32);

--------------------------------------------------------------------------------
-- SETUP: Test accounts in auth.users
--------------------------------------------------------------------------------
-- User 1: Active Learner in Asia/Kolkata
-- User 2: Second Active Learner in UTC
-- User 3: Admin User in Europe/Berlin
-- User 4: Inactive Learner in UTC
-- User 5: Inactive Admin in UTC

INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'learner1@test.local', '{"display_name": "Learner One", "teaching_language": "tamil", "timezone": "Asia/Kolkata"}'::jsonb),
  ('22222222-2222-2222-2222-222222222222', 'learner2@test.local', '{"display_name": "Learner Two", "teaching_language": "english", "timezone": "UTC"}'::jsonb),
  ('33333333-3333-3333-3333-333333333333', 'admin@test.local', '{"display_name": "Admin User", "teaching_language": "english", "timezone": "Europe/Berlin"}'::jsonb),
  ('44444444-4444-4444-4444-444444444444', 'inactive@test.local', '{"display_name": "Inactive User", "teaching_language": "tamil", "timezone": "UTC"}'::jsonb),
  ('55555555-5555-5555-5555-555555555555', 'inactiveadmin@test.local', '{"display_name": "Inactive Admin", "teaching_language": "english", "timezone": "UTC"}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- Promote User 3 to admin (trusted SQL-editor simulation)
UPDATE public.profiles
SET role = 'admin'
WHERE id = '33333333-3333-3333-3333-333333333333';

-- Deactivate User 4
UPDATE public.profiles
SET is_active = false
WHERE id = '44444444-4444-4444-4444-444444444444';

-- Setup User 5 as inactive admin
UPDATE public.profiles
SET role = 'admin', is_active = false
WHERE id = '55555555-5555-5555-5555-555555555555';

--------------------------------------------------------------------------------
-- 1. Signup trigger enforces defaults (role='learner', is_active=true)
--------------------------------------------------------------------------------
INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES (
  '66666666-6666-6666-6666-666666666666',
  'tamper@test.local',
  '{"display_name": "Attacker", "role": "admin", "is_active": false, "timezone": "Asia/Kolkata"}'::jsonb
);

SELECT results_eq(
  'SELECT role, is_active FROM public.profiles WHERE id = ''66666666-6666-6666-6666-666666666666''',
  $$VALUES ('learner'::text, true)$$,
  '1: Signup trigger forces role=learner and is_active=true despite client metadata'
);

--------------------------------------------------------------------------------
-- 2. Timezone validation: rejects invalid, NULL, or empty timezone values
--------------------------------------------------------------------------------
SELECT throws_ok(
  'UPDATE public.profiles SET timezone = ''Mars/Base'' WHERE id = ''11111111-1111-1111-1111-111111111111''',
  '22023',
  '2: Invalid IANA timezone must be rejected by validation trigger'
);

SELECT throws_ok(
  'UPDATE public.profiles SET timezone = '''' WHERE id = ''11111111-1111-1111-1111-111111111111''',
  '22023',
  '3: Empty timezone string must be rejected by validation trigger'
);

--------------------------------------------------------------------------------
-- 3. Inactive learner: self-SELECT works, but UPDATE fails RLS
--------------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '44444444-4444-4444-4444-444444444444';

SELECT results_eq(
  'SELECT is_active FROM public.profiles WHERE id = ''44444444-4444-4444-4444-444444444444''',
  $$VALUES (false)$$,
  '4: Inactive user can SELECT their own profile row'
);

-- Inactive user update filtered by RLS (0 rows affected)
UPDATE public.profiles
SET display_name = 'Cannot Update'
WHERE id = '44444444-4444-4444-4444-444444444444';

SELECT results_eq(
  'SELECT display_name FROM public.profiles WHERE id = ''44444444-4444-4444-4444-444444444444''',
  $$VALUES ('Inactive User'::text)$$,
  '5: Inactive user cannot UPDATE own profile (RLS filters out inactive user)'
);

--------------------------------------------------------------------------------
-- 4. Cross-user profile isolation & protected column permission checks
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

SELECT is_empty(
  'SELECT * FROM public.profiles WHERE id = ''22222222-2222-2222-2222-222222222222''',
  '6: Learner 1 cannot read Learner 2 profile'
);

SELECT throws_ok(
  'UPDATE public.profiles SET role = ''admin'' WHERE id = ''11111111-1111-1111-1111-111111111111''',
  '42501',
  '7: Updating role throws 42501 column permission denied'
);

SELECT throws_ok(
  'UPDATE public.profiles SET is_active = false WHERE id = ''11111111-1111-1111-1111-111111111111''',
  '42501',
  '8: Updating is_active throws 42501 column permission denied'
);

--------------------------------------------------------------------------------
-- 5. Learning events: permission errors on forged columns, UPDATE, and DELETE
--------------------------------------------------------------------------------
SELECT throws_ok(
  'INSERT INTO public.learning_events (id, user_id, event_type) VALUES (gen_random_uuid(), ''11111111-1111-1111-1111-111111111111'', ''lesson_completed'')',
  '42501',
  '9: Inserting explicit user_id throws 42501 (column privilege restriction)'
);

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, created_at, event_type) VALUES (gen_random_uuid(), now(), ''lesson_completed'')',
  '42501',
  '10: Inserting explicit created_at throws 42501'
);

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, reward_date, event_type) VALUES (gen_random_uuid(), current_date, ''lesson_completed'')',
  '42501',
  '11: Inserting explicit reward_date throws 42501'
);

SELECT throws_ok(
  'UPDATE public.learning_events SET event_type = ''lesson_completed'' WHERE id = gen_random_uuid()',
  '42501',
  '12: Updating learning_events throws 42501 (append-only)'
);

SELECT throws_ok(
  'DELETE FROM public.learning_events WHERE id = gen_random_uuid()',
  '42501',
  '13: Deleting from learning_events throws 42501 (append-only)'
);

--------------------------------------------------------------------------------
-- 6. Event validation constraints: exercise_id requirement & invalid types
--------------------------------------------------------------------------------
SELECT throws_ok(
  'INSERT INTO public.learning_events (id, event_type) VALUES (gen_random_uuid(), ''exercise_correct'')',
  '23514',
  '14: exercise_correct without exercise_id violates check constraint'
);

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, event_type) VALUES (gen_random_uuid(), ''exercise_incorrect'')',
  '23514',
  '15: exercise_incorrect without exercise_id violates check constraint'
);

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, event_type) VALUES (gen_random_uuid(), ''hack_xp'')',
  '23514',
  '16: Event type outside allowlist violates check constraint'
);

--------------------------------------------------------------------------------
-- 7. Missing profile raises P0002 on event insert (no UTC fallback)
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claim.sub" = '99999999-9999-9999-9999-999999999999';

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, event_type) VALUES (gen_random_uuid(), ''lesson_completed'')',
  'P0002',
  '17: Inserting event for user without profile raises P0002 (no UTC fallback)'
);

--------------------------------------------------------------------------------
-- 8. Valid insertion, server-derived reward_date, and cross-user event isolation
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

INSERT INTO public.learning_events (id, event_type, exercise_id)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'exercise_correct',
  'ex-101'
);

SELECT results_eq(
  'SELECT reward_date FROM public.learning_events WHERE id = ''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa''',
  $$SELECT (now() AT TIME ZONE 'Asia/Kolkata')::date$$,
  '18: Event BEFORE INSERT trigger sets reward_date in user timezone (Asia/Kolkata)'
);

-- Learner 2 cannot read Learner 1 events
SET LOCAL "request.jwt.claim.sub" = '22222222-2222-2222-2222-222222222222';

SELECT is_empty(
  'SELECT * FROM public.learning_events WHERE id = ''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa''',
  '19: Cross-user learning event read returns zero rows'
);

--------------------------------------------------------------------------------
-- 9. Stable constraint names & daily duplicate exercise rejection
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

-- Primary key constraint name: learning_events_pkey
SELECT throws_like(
  'INSERT INTO public.learning_events (id, event_type, exercise_id) VALUES (''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'', ''exercise_correct'', ''ex-diff'')',
  '%violates unique constraint "learning_events_pkey"%',
  '20: Retrying identical event id throws 23505 on learning_events_pkey'
);

-- Daily exercise unique constraint name: idx_events_exercise_daily
SELECT throws_like(
  'INSERT INTO public.learning_events (id, event_type, exercise_id) VALUES (gen_random_uuid(), ''exercise_correct'', ''ex-101'')',
  '%violates unique constraint "idx_events_exercise_daily"%',
  '21: Same exercise_correct on same reward_date throws 23505 on idx_events_exercise_daily'
);

-- exercise_incorrect is outside idx_events_exercise_daily (allowed multiple times)
SELECT lives_ok(
  'INSERT INTO public.learning_events (id, event_type, exercise_id) VALUES (gen_random_uuid(), ''exercise_incorrect'', ''ex-101'')',
  '22: exercise_incorrect is outside partial daily index and succeeds'
);

--------------------------------------------------------------------------------
-- 10. Feedback: column grants, status tampering, and cross-user read isolation
--------------------------------------------------------------------------------
SELECT throws_ok(
  'INSERT INTO public.feedback (category, message, status) VALUES (''bug'', ''Cannot submit pre-resolved'', ''resolved'')',
  '42501',
  '23: Inserting explicit status on feedback throws 42501'
);

SELECT throws_ok(
  'INSERT INTO public.feedback (category, message) VALUES (''bug'', ''    '')',
  '23514',
  '24: Whitespace-only feedback message violates check constraint'
);

INSERT INTO public.feedback (category, message)
VALUES ('bug', 'Audio glitch on lesson greetings');

-- Learner 2 cannot read Learner 1 feedback
SET LOCAL "request.jwt.claim.sub" = '22222222-2222-2222-2222-222222222222';

SELECT is_empty(
  'SELECT * FROM public.feedback WHERE user_id = ''11111111-1111-1111-1111-111111111111''',
  '25: Cross-user feedback read returns zero rows'
);

--------------------------------------------------------------------------------
-- 11. Timezone change does not rewrite historical reward_date
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

UPDATE public.profiles
SET timezone = 'Pacific/Auckland'
WHERE id = '11111111-1111-1111-1111-111111111111';

SELECT results_eq(
  'SELECT reward_date FROM public.learning_events WHERE id = ''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa''',
  $$SELECT (now() AT TIME ZONE 'Asia/Kolkata')::date$$,
  '26: Timezone update on profile does not alter historical event reward_date'
);

--------------------------------------------------------------------------------
-- 12. RPC authorization: Non-admin and inactive admin calls rejected
--------------------------------------------------------------------------------
-- Active learner cannot call admin RPC
SELECT throws_like(
  'SELECT public.admin_set_user_active(''22222222-2222-2222-2222-222222222222'', false)',
  '%Access denied: caller is not an active administrator.%',
  '27: Learner calling admin_set_user_active throws access denied'
);

-- Inactive admin cannot call admin RPC
SET LOCAL "request.jwt.claim.sub" = '55555555-5555-5555-5555-555555555555';

SELECT throws_like(
  'SELECT public.get_admin_learner_summary(''11111111-1111-1111-1111-111111111111'')',
  '%Access denied: caller is not an active administrator.%',
  '28: Inactive admin calling get_admin_learner_summary throws access denied'
);

--------------------------------------------------------------------------------
-- 13. Active admin operations and self-deactivation rejection
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claim.sub" = '33333333-3333-3333-3333-333333333333';

SELECT throws_like(
  'SELECT public.admin_set_user_active(''33333333-3333-3333-3333-333333333333'', false)',
  '%administrators cannot deactivate their own account%',
  '29: Active admin cannot deactivate self'
);

SELECT lives_ok(
  'SELECT public.admin_set_user_active(''22222222-2222-2222-2222-222222222222'', false)',
  '30: Active admin can deactivate other learner account'
);

--------------------------------------------------------------------------------
-- 14. XP Cap (200 XP/day) and Streak calculation (exercise_incorrect counts)
--------------------------------------------------------------------------------
-- Setup streak and cap fixtures for user 2:
-- Reset user 2 active status for fixture setup
UPDATE public.profiles SET is_active = true, timezone = 'UTC' WHERE id = '22222222-2222-2222-2222-222222222222';

-- Day T-2: 5 lessons = 250 raw XP -> capped at 200 XP
-- Day T-1: Only exercise_incorrect (0 XP) -> keeps streak alive!
-- Day T (Today): 1 lesson = 50 XP
-- Expected XP = 200 + 0 + 50 = 250 XP
-- Expected Streak = 3 days

INSERT INTO public.learning_events (id, user_id, event_type, lesson_id, exercise_id, reward_date, created_at)
VALUES
  -- Day T-2 (2 days ago)
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-1', NULL, current_date - 2, now() - interval '2 days'),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-2', NULL, current_date - 2, now() - interval '2 days'),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-3', NULL, current_date - 2, now() - interval '2 days'),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-4', NULL, current_date - 2, now() - interval '2 days'),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-5', NULL, current_date - 2, now() - interval '2 days'),
  -- Day T-1 (Yesterday): only incorrect answer
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'exercise_incorrect', NULL, 'ex-hard', current_date - 1, now() - interval '1 day'),
  -- Day T (Today)
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-today', NULL, current_date, now());

SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''22222222-2222-2222-2222-222222222222'')->>''server_derived_xp'')::integer',
  $$VALUES (250)$$,
  '31: Daily 200 XP cap respected: 250 raw XP on T-2 capped to 200 + 0 on T-1 + 50 on T = 250 XP'
);

SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''22222222-2222-2222-2222-222222222222'')->>''current_day_streak'')::integer',
  $$VALUES (3)$$,
  '32: Streak is 3 consecutive days; day with only exercise_incorrect maintains streak'
);

SELECT * FROM finish();
ROLLBACK;
