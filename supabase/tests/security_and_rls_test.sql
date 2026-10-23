-- Supabase pgTAP / SQL Test Suite: DeutschMate Database Security & RLS Verification
-- Execute in a local test environment with pgTAP enabled.
-- DO NOT RUN ON PRODUCTION.

BEGIN;
SELECT plan(22);

-- Setup 3 test accounts in auth.users
-- User 1: Active Learner
-- User 2: Second Learner
-- User 3: Admin User
-- User 4: Inactive Learner

INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'learner1@test.local', '{"display_name": "Learner One", "teaching_language": "tamil"}'::jsonb),
  ('22222222-2222-2222-2222-222222222222', 'learner2@test.local', '{"display_name": "Learner Two", "teaching_language": "english"}'::jsonb),
  ('33333333-3333-3333-3333-333333333333', 'admin@test.local', '{"display_name": "Admin User", "teaching_language": "english"}'::jsonb),
  ('44444444-4444-4444-4444-444444444444', 'inactive@test.local', '{"display_name": "Inactive User", "teaching_language": "tamil"}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- Promote user 3 to admin (trusted SQL-editor simulation)
UPDATE public.profiles
SET role = 'admin'
WHERE id = '33333333-3333-3333-3333-333333333333';

-- Deactivate user 4
UPDATE public.profiles
SET is_active = false
WHERE id = '44444444-4444-4444-4444-444444444444';

--------------------------------------------------------------------------------
-- TEST 1: Signup metadata cannot grant admin role or false active status
--------------------------------------------------------------------------------
INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES (
  '55555555-5555-5555-5555-555555555555',
  'hacker@test.local',
  '{"display_name": "Hacker", "role": "admin", "is_active": false}'::jsonb
);

SELECT results_eq(
  'SELECT role, is_active FROM public.profiles WHERE id = ''55555555-5555-5555-5555-555555555555''',
  $$VALUES ('learner'::text, true)$$,
  'Signup trigger must ignore client-supplied role/active status and force role=learner, is_active=true'
);

--------------------------------------------------------------------------------
-- TEST 2: Users cannot read another user profile
--------------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

SELECT is_empty(
  'SELECT * FROM public.profiles WHERE id = ''22222222-2222-2222-2222-222222222222''',
  'Learner 1 must not be able to read Learner 2 profile'
);

SELECT results_eq(
  'SELECT id FROM public.profiles WHERE id = ''11111111-1111-1111-1111-111111111111''',
  $$VALUES ('11111111-1111-1111-1111-111111111111'::uuid)$$,
  'Learner 1 must be able to read own profile'
);

--------------------------------------------------------------------------------
-- TEST 3: Users cannot update their own role or is_active (Column Privilege Error)
--------------------------------------------------------------------------------
SELECT throws_like(
  'UPDATE public.profiles SET role = ''admin'' WHERE id = ''11111111-1111-1111-1111-111111111111''',
  '%permission denied for table profiles%',
  'Learner updating role must trigger PostgreSQL column permission denied error'
);

SELECT throws_like(
  'UPDATE public.profiles SET is_active = false WHERE id = ''11111111-1111-1111-1111-111111111111''',
  '%permission denied for table profiles%',
  'Learner updating is_active must trigger PostgreSQL column permission denied error'
);

-- Allowed columns update succeeds
UPDATE public.profiles
SET display_name = 'Kavitha Updated', teaching_language = 'english'
WHERE id = '11111111-1111-1111-1111-111111111111';

SELECT results_eq(
  'SELECT display_name, teaching_language FROM public.profiles WHERE id = ''11111111-1111-1111-1111-111111111111''',
  $$VALUES ('Kavitha Updated'::text, 'english'::text)$$,
  'Learner can update own display_name and teaching_language'
);

--------------------------------------------------------------------------------
-- TEST 4: Users cannot insert events attributed to another user
--------------------------------------------------------------------------------
SELECT throws_ok(
  'INSERT INTO public.learning_events (id, user_id, event_type) VALUES (gen_random_uuid(), ''22222222-2222-2222-2222-222222222222'', ''lesson_completed'')',
  'new row violates row-level security policy for table "learning_events"',
  'Learner 1 cannot insert learning event with Learner 2 user_id'
);

-- Learner inserts own event
INSERT INTO public.learning_events (id, user_id, event_type, exercise_id)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111',
  'exercise_correct',
  'ex-101'
);

SELECT results_eq(
  'SELECT exercise_id FROM public.learning_events WHERE id = ''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa''',
  $$VALUES ('ex-101'::text)$$,
  'Learner 1 can read own inserted event'
);

--------------------------------------------------------------------------------
-- TEST 5: Duplicate event insertion (Idempotency Key Check)
--------------------------------------------------------------------------------
SELECT throws_like(
  'INSERT INTO public.learning_events (id, user_id, event_type, exercise_id) VALUES (''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'', ''11111111-1111-1111-1111-111111111111'', ''exercise_correct'', ''ex-101'')',
  '%duplicate key value violates unique constraint "learning_events_pkey"%',
  'Retried event with same client UUID must be rejected by primary key idempotency'
);

--------------------------------------------------------------------------------
-- TEST 6: Repeated exercise on same server UTC day rejected by unique index
--------------------------------------------------------------------------------
SELECT throws_like(
  'INSERT INTO public.learning_events (id, user_id, event_type, exercise_id) VALUES (gen_random_uuid(), ''11111111-1111-1111-1111-111111111111'', ''exercise_correct'', ''ex-101'')',
  '%duplicate key value violates unique constraint "idx_learning_events_exercise_daily_unique"%',
  'Same exercise completed twice on same UTC date must be rejected by daily uniqueness constraint'
);

--------------------------------------------------------------------------------
-- TEST 7: Users cannot UPDATE or DELETE learning events
--------------------------------------------------------------------------------
UPDATE public.learning_events
SET event_type = 'lesson_completed'
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Assert 0 rows updated and stored row is unchanged
SELECT results_eq(
  'SELECT event_type FROM public.learning_events WHERE id = ''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa''',
  $$VALUES ('exercise_correct'::text)$$,
  'Learning events table is append-only: UPDATE has no matching policy and affects 0 rows'
);

DELETE FROM public.learning_events
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT results_eq(
  'SELECT COUNT(*)::integer FROM public.learning_events WHERE id = ''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa''',
  $$VALUES (1)$$,
  'Learning events table is append-only: DELETE has no matching policy and deletes 0 rows'
);

--------------------------------------------------------------------------------
-- TEST 8: Feedback RLS and status tampering prevention
--------------------------------------------------------------------------------
-- Learner inserts feedback with status = 'new'
INSERT INTO public.feedback (id, user_id, category, message, status)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '11111111-1111-1111-1111-111111111111',
  'bug',
  'Pronunciation audio fails on chapter 1',
  'new'
);

-- Learner attempting to insert feedback with status = 'resolved' must be blocked
SELECT throws_ok(
  'INSERT INTO public.feedback (id, user_id, category, message, status) VALUES (gen_random_uuid(), ''11111111-1111-1111-1111-111111111111'', ''bug'', ''Cannot resolve myself'', ''resolved'')',
  'new row violates row-level security policy for table "feedback"',
  'Learner cannot submit feedback pre-marked as resolved'
);

-- Learner attempting to update status via SQL fails
SELECT throws_like(
  'UPDATE public.feedback SET status = ''resolved'' WHERE id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  '%permission denied for table feedback%',
  'Direct UPDATE on feedback is revoked from authenticated role'
);

--------------------------------------------------------------------------------
-- TEST 9: Inactive user blocked from inserting data
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claim.sub" = '44444444-4444-4444-4444-444444444444';

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, user_id, event_type) VALUES (gen_random_uuid(), ''44444444-4444-4444-4444-444444444444'', ''lesson_completed'')',
  'new row violates row-level security policy for table "learning_events"',
  'Inactive user cannot insert learning events'
);

SELECT throws_ok(
  'INSERT INTO public.feedback (user_id, category, message) VALUES (''44444444-4444-4444-4444-444444444444'', ''suggestion'', ''Please reactivate me'')',
  'new row violates row-level security policy for table "feedback"',
  'Inactive user cannot submit feedback'
);

--------------------------------------------------------------------------------
-- TEST 10: Non-admin cannot call admin RPCs
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

SELECT throws_like(
  'SELECT public.admin_set_user_active(''22222222-2222-2222-2222-222222222222'', false)',
  '%Access denied: caller is not an active administrator.%',
  'Learner cannot call admin_set_user_active'
);

SELECT throws_like(
  'SELECT public.admin_set_feedback_status(''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'', ''resolved'')',
  '%Access denied: caller is not an active administrator.%',
  'Learner cannot call admin_set_feedback_status'
);

SELECT throws_like(
  'SELECT public.get_admin_learner_summary(''22222222-2222-2222-2222-222222222222'')',
  '%Access denied: caller is not an active administrator.%',
  'Learner cannot call get_admin_learner_summary'
);

--------------------------------------------------------------------------------
-- TEST 11: Admin capabilities and self-deactivation rejection
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claim.sub" = '33333333-3333-3333-3333-333333333333';

-- Admin reads all profiles
SELECT results_eq(
  'SELECT COUNT(*)::integer FROM public.profiles',
  $$VALUES (5)$$,
  'Admin can read all profiles via RLS policy'
);

-- Admin modifies feedback status through RPC
SELECT lives_ok(
  'SELECT public.admin_set_feedback_status(''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'', ''resolved'')',
  'Admin can set feedback status to resolved via RPC'
);

-- Admin deactivates Learner 2
SELECT lives_ok(
  'SELECT public.admin_set_user_active(''22222222-2222-2222-2222-222222222222'', false)',
  'Admin can deactivate other user'
);

-- Admin self-deactivation rejected
SELECT throws_like(
  'SELECT public.admin_set_user_active(''33333333-3333-3333-3333-333333333333'', false)',
  '%administrators cannot deactivate their own account%',
  'Admin cannot deactivate self'
);

-- Admin summary returns server-derived aggregates
SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''11111111-1111-1111-1111-111111111111'')->>''server_derived_xp'')::integer',
  $$VALUES (10)$$,
  'Admin summary calculates exact server-derived XP from exercise event'
);

SELECT * FROM finish();
ROLLBACK;
