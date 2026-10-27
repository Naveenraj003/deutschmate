-- Supabase pgTAP / SQL Test Suite: DeutschMate Database Security & RLS Verification
-- Execute in a local test environment with pgTAP enabled.
-- DO NOT RUN ON PRODUCTION.

BEGIN;
SELECT plan(67);

--------------------------------------------------------------------------------
-- SETUP: Test accounts in auth.users
--------------------------------------------------------------------------------
-- User 1: Active Learner in Asia/Kolkata
-- User 2: Second Active Learner in UTC
-- User 3: Admin User in Europe/Berlin
-- User 4: Inactive Learner in UTC
-- User 5: Inactive Admin in UTC
-- User 6: Streak Case A (today, -1, -2) in UTC
-- User 7: Streak Case B (-1, -2) in UTC
-- User 8: Streak Case C (today, -2) in UTC
-- User 9: Streak Case D (-2, -3) in UTC
-- User 10: Streak Case E (-1 incorrect-only, -2 lesson) in UTC

INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'learner1@test.local', '{"display_name": "Learner One", "teaching_language": "tamil", "timezone": "Asia/Kolkata"}'::jsonb),
  ('22222222-2222-2222-2222-222222222222', 'learner2@test.local', '{"display_name": "Learner Two", "teaching_language": "english", "timezone": "UTC"}'::jsonb),
  ('33333333-3333-3333-3333-333333333333', 'admin@test.local', '{"display_name": "Admin User", "teaching_language": "english", "timezone": "Europe/Berlin"}'::jsonb),
  ('44444444-4444-4444-4444-444444444444', 'inactive@test.local', '{"display_name": "Inactive User", "teaching_language": "tamil", "timezone": "UTC"}'::jsonb),
  ('55555555-5555-5555-5555-555555555555', 'inactiveadmin@test.local', '{"display_name": "Inactive Admin", "teaching_language": "english", "timezone": "UTC"}'::jsonb),
  ('aaaaaaaa-0000-0000-0000-aaaaaaaaaaaa', 'casea@test.local', '{"display_name": "Case A", "teaching_language": "english", "timezone": "UTC"}'::jsonb),
  ('bbbbbbbb-0000-0000-0000-bbbbbbbbbbbb', 'caseb@test.local', '{"display_name": "Case B", "teaching_language": "english", "timezone": "UTC"}'::jsonb),
  ('cccccccc-0000-0000-0000-cccccccccccc', 'casec@test.local', '{"display_name": "Case C", "teaching_language": "english", "timezone": "UTC"}'::jsonb),
  ('dddddddd-0000-0000-0000-dddddddddddd', 'cased@test.local', '{"display_name": "Case D", "teaching_language": "english", "timezone": "UTC"}'::jsonb),
  ('eeeeeeee-0000-0000-0000-eeeeeeeeeeee', 'casee@test.local', '{"display_name": "Case E", "teaching_language": "english", "timezone": "UTC"}'::jsonb)
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
-- PRIVILEGED SEEDING: Seed fixtures for Inactive User 4 and Streak Cases A-E
-- (Performed before switching to authenticated role with triggers temporarily disabled)
--------------------------------------------------------------------------------
ALTER TABLE public.learning_events DISABLE TRIGGER trg_learning_events_set_server_fields;

-- Seed historical event & feedback for Inactive User 4
INSERT INTO public.learning_events (id, user_id, event_type, reward_date, created_at)
VALUES (
  '44444444-1111-1111-1111-444444444444',
  '44444444-4444-4444-4444-444444444444',
  'lesson_completed',
  public.local_reward_date(now(), 'UTC') - 5,
  now() - interval '5 days'
);

INSERT INTO public.feedback (id, user_id, category, message, status, created_at)
VALUES (
  '44444444-2222-2222-2222-444444444444',
  '44444444-4444-4444-4444-444444444444',
  'suggestion',
  'Historical feedback from when I was active',
  'new',
  now() - interval '5 days'
);

-- Seed Streak Case A: today, -1, -2 => current_day_streak = 3
INSERT INTO public.learning_events (id, user_id, event_type, reward_date, created_at)
VALUES
  (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-aaaaaaaaaaaa', 'lesson_completed', public.local_reward_date(now(), 'UTC') - 2, now() - interval '2 days'),
  (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-aaaaaaaaaaaa', 'lesson_completed', public.local_reward_date(now(), 'UTC') - 1, now() - interval '1 day'),
  (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-aaaaaaaaaaaa', 'lesson_completed', public.local_reward_date(now(), 'UTC'), now());

-- Seed Streak Case B: -1, -2 => current_day_streak = 2 (ended yesterday)
INSERT INTO public.learning_events (id, user_id, event_type, reward_date, created_at)
VALUES
  (gen_random_uuid(), 'bbbbbbbb-0000-0000-0000-bbbbbbbbbbbb', 'lesson_completed', public.local_reward_date(now(), 'UTC') - 2, now() - interval '2 days'),
  (gen_random_uuid(), 'bbbbbbbb-0000-0000-0000-bbbbbbbbbbbb', 'lesson_completed', public.local_reward_date(now(), 'UTC') - 1, now() - interval '1 day');

-- Seed Streak Case C: today, -2 => current_day_streak = 1 (gap on -1 breaks run)
INSERT INTO public.learning_events (id, user_id, event_type, reward_date, created_at)
VALUES
  (gen_random_uuid(), 'cccccccc-0000-0000-0000-cccccccccccc', 'lesson_completed', public.local_reward_date(now(), 'UTC') - 2, now() - interval '2 days'),
  (gen_random_uuid(), 'cccccccc-0000-0000-0000-cccccccccccc', 'lesson_completed', public.local_reward_date(now(), 'UTC'), now());

-- Seed Streak Case D: -2, -3 => current_day_streak = 0 (ended 2 days ago)
INSERT INTO public.learning_events (id, user_id, event_type, reward_date, created_at)
VALUES
  (gen_random_uuid(), 'dddddddd-0000-0000-0000-dddddddddddd', 'lesson_completed', public.local_reward_date(now(), 'UTC') - 3, now() - interval '3 days'),
  (gen_random_uuid(), 'dddddddd-0000-0000-0000-dddddddddddd', 'lesson_completed', public.local_reward_date(now(), 'UTC') - 2, now() - interval '2 days');

-- Seed Streak Case E: -1 incorrect-only plus -2 lesson => current_day_streak = 2
INSERT INTO public.learning_events (id, user_id, event_type, exercise_id, reward_date, created_at)
VALUES
  (gen_random_uuid(), 'eeeeeeee-0000-0000-0000-eeeeeeeeeeee', 'lesson_completed', NULL, public.local_reward_date(now(), 'UTC') - 2, now() - interval '2 days'),
  (gen_random_uuid(), 'eeeeeeee-0000-0000-0000-eeeeeeeeeeee', 'exercise_incorrect', 'ex-fail', public.local_reward_date(now(), 'UTC') - 1, now() - interval '1 day');

-- Seed User 2 XP-Cap Fixture: Day T-2 5 lessons (250 raw XP) + Day T-1 incorrect (0 XP) + Day T lesson (50 XP)
INSERT INTO public.learning_events (id, user_id, event_type, lesson_id, exercise_id, reward_date, created_at)
VALUES
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-1', NULL, public.local_reward_date(now(), 'UTC') - 2, now() - interval '2 days'),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-2', NULL, public.local_reward_date(now(), 'UTC') - 2, now() - interval '2 days'),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-3', NULL, public.local_reward_date(now(), 'UTC') - 2, now() - interval '2 days'),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-4', NULL, public.local_reward_date(now(), 'UTC') - 2, now() - interval '2 days'),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-5', NULL, public.local_reward_date(now(), 'UTC') - 2, now() - interval '2 days'),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'exercise_incorrect', NULL, 'ex-hard', public.local_reward_date(now(), 'UTC') - 1, now() - interval '1 day'),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'lesson_completed', 'l-today', NULL, public.local_reward_date(now(), 'UTC'), now());

ALTER TABLE public.learning_events ENABLE TRIGGER trg_learning_events_set_server_fields;

-- Privileged assertion: verify inactive learner rows exist in database
SELECT results_eq(
  'SELECT count(*)::integer FROM public.learning_events WHERE user_id = ''44444444-4444-4444-4444-444444444444''',
  $$VALUES (1)$$,
  '1: Privileged check: seeded learning event exists for Inactive User 4'
);

SELECT results_eq(
  'SELECT count(*)::integer FROM public.feedback WHERE user_id = ''44444444-4444-4444-4444-444444444444''',
  $$VALUES (1)$$,
  '2: Privileged check: seeded feedback exists for Inactive User 4'
);

--------------------------------------------------------------------------------
-- 1. Unit tests for public.local_reward_date (Asia/Kolkata UTC+5:30 midnight boundary)
--------------------------------------------------------------------------------
SELECT results_eq(
  $$SELECT public.local_reward_date('2026-05-10 18:29:59+00'::timestamptz, 'Asia/Kolkata')$$,
  $$VALUES ('2026-05-10'::date)$$,
  '3: local_reward_date at 18:29:59 UTC in Asia/Kolkata resolves to 2026-05-10'
);

SELECT results_eq(
  $$SELECT public.local_reward_date('2026-05-10 18:30:00+00'::timestamptz, 'Asia/Kolkata')$$,
  $$VALUES ('2026-05-11'::date)$$,
  '4: local_reward_date at 18:30:00 UTC in Asia/Kolkata resolves to 2026-05-11'
);

--------------------------------------------------------------------------------
-- 2. Signup trigger enforces defaults (role='learner', is_active=true)
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
  '5: Signup trigger forces role=learner and is_active=true despite client metadata'
);

--------------------------------------------------------------------------------
-- 3. Timezone validation: rejects invalid, NULL, or empty timezone values
--------------------------------------------------------------------------------
SELECT throws_ok(
  'UPDATE public.profiles SET timezone = ''Mars/Base'' WHERE id = ''11111111-1111-1111-1111-111111111111''',
  '22023',
  '6: Invalid IANA timezone must be rejected by validation trigger'
);

SELECT throws_ok(
  'UPDATE public.profiles SET timezone = '''' WHERE id = ''11111111-1111-1111-1111-111111111111''',
  '22023',
  '7: Empty timezone string must be rejected by validation trigger'
);

--------------------------------------------------------------------------------
-- 4. Inactive learner: self-SELECT works, but UPDATE, INSERT, and event/feedback reads fail
--------------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '44444444-4444-4444-4444-444444444444';

-- Positive control: inactive learner reads own profile
SELECT results_eq(
  'SELECT id, is_active FROM public.profiles WHERE id = ''44444444-4444-4444-4444-444444444444''',
  $$VALUES ('44444444-4444-4444-4444-444444444444'::uuid, false)$$,
  '8: Inactive user can SELECT their own profile row'
);

-- Inactive user update filtered by RLS (0 rows affected)
UPDATE public.profiles
SET display_name = 'Cannot Update'
WHERE id = '44444444-4444-4444-4444-444444444444';

SELECT results_eq(
  'SELECT display_name FROM public.profiles WHERE id = ''44444444-4444-4444-4444-444444444444''',
  $$VALUES ('Inactive User'::text)$$,
  '9: Inactive user cannot UPDATE own profile (stored value unchanged)'
);

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, event_type) VALUES (gen_random_uuid(), ''lesson_completed'')',
  '42501',
  '10: Inactive learner cannot insert learning events (RLS with check fails)'
);

SELECT throws_ok(
  'INSERT INTO public.feedback (category, message) VALUES (''bug'', ''Please unblock me'')',
  '42501',
  '11: Inactive learner cannot insert feedback (RLS with check fails)'
);

SELECT is_empty(
  'SELECT * FROM public.learning_events WHERE user_id = ''44444444-4444-4444-4444-444444444444''',
  '12: Inactive learner cannot read own learning events'
);

SELECT is_empty(
  'SELECT * FROM public.feedback WHERE user_id = ''44444444-4444-4444-4444-444444444444''',
  '13: Inactive learner cannot read own feedback'
);

--------------------------------------------------------------------------------
-- 5. Cross-user profile isolation & protected column permission checks
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

-- Positive control: Learner 1 confirms identity and reads own profile
SELECT results_eq(
  'SELECT id FROM public.profiles WHERE id = (SELECT auth.uid())',
  $$VALUES ('11111111-1111-1111-1111-111111111111'::uuid)$$,
  '14: Positive control: Learner 1 can read own profile'
);

SELECT is_empty(
  'SELECT * FROM public.profiles WHERE id = ''22222222-2222-2222-2222-222222222222''',
  '15: Learner 1 cannot read Learner 2 profile'
);

SELECT throws_ok(
  'UPDATE public.profiles SET role = ''admin'' WHERE id = ''11111111-1111-1111-1111-111111111111''',
  '42501',
  '16: Updating role throws 42501 column permission denied'
);

SELECT throws_ok(
  'UPDATE public.profiles SET is_active = false WHERE id = ''11111111-1111-1111-1111-111111111111''',
  '42501',
  '17: Updating is_active throws 42501 column permission denied'
);

--------------------------------------------------------------------------------
-- 6. Learning events: permission errors on forged columns, UPDATE, and DELETE
--------------------------------------------------------------------------------
SELECT throws_ok(
  'INSERT INTO public.learning_events (id, user_id, event_type) VALUES (gen_random_uuid(), ''11111111-1111-1111-1111-111111111111'', ''lesson_completed'')',
  '42501',
  '18: Inserting explicit user_id throws 42501 (column privilege restriction)'
);

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, created_at, event_type) VALUES (gen_random_uuid(), now(), ''lesson_completed'')',
  '42501',
  '19: Inserting explicit created_at throws 42501'
);

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, reward_date, event_type) VALUES (gen_random_uuid(), current_date, ''lesson_completed'')',
  '42501',
  '20: Inserting explicit reward_date throws 42501'
);

SELECT throws_ok(
  'UPDATE public.learning_events SET event_type = ''lesson_completed'' WHERE id = gen_random_uuid()',
  '42501',
  '21: Updating learning_events throws 42501 (append-only)'
);

SELECT throws_ok(
  'DELETE FROM public.learning_events WHERE id = gen_random_uuid()',
  '42501',
  '22: Deleting from learning_events throws 42501 (append-only)'
);

--------------------------------------------------------------------------------
-- 7. Split exercise_id constraints & event type validation
--------------------------------------------------------------------------------
SELECT throws_ok(
  'INSERT INTO public.learning_events (id, event_type) VALUES (gen_random_uuid(), ''exercise_correct'')',
  '23514',
  '23: exercise_correct without exercise_id violates check constraint'
);

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, event_type) VALUES (gen_random_uuid(), ''exercise_incorrect'')',
  '23514',
  '24: exercise_incorrect without exercise_id violates check constraint'
);

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, event_type, exercise_id) VALUES (gen_random_uuid(), ''lesson_completed'', repeat(''x'', 65))',
  '23514',
  '25: exercise_id > 64 chars violates check_exercise_id_format'
);

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, event_type) VALUES (gen_random_uuid(), ''hack_xp'')',
  '23514',
  '26: Event type outside allowlist violates check constraint'
);

--------------------------------------------------------------------------------
-- 8. Missing profile raises P0002 on event insert (no UTC fallback)
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999999999", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '99999999-9999-9999-9999-999999999999';

SELECT throws_ok(
  'INSERT INTO public.learning_events (id, event_type) VALUES (gen_random_uuid(), ''lesson_completed'')',
  'P0002',
  '27: Inserting event for user without profile raises P0002 (no UTC fallback)'
);

--------------------------------------------------------------------------------
-- 9. 48-Hour Timestamp Clamping: In-window (-20h), Future (+10d), Stale (-30d), and NULL
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

-- Case A: client_created_at is NULL -> defaults to now()
INSERT INTO public.learning_events (id, event_type, exercise_id, client_created_at)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'exercise_correct',
  'ex-101',
  NULL
);

SELECT results_eq(
  'SELECT reward_date FROM public.learning_events WHERE id = ''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa''',
  $$SELECT public.local_reward_date(now(), 'Asia/Kolkata')$$,
  '28: Event with NULL client_created_at uses now() in Asia/Kolkata'
);

-- Case B: in-window client_created_at (-20 hours) -> uses exact -20h timestamp
INSERT INTO public.learning_events (id, event_type, exercise_id, client_created_at)
VALUES (
  '11111111-2020-2020-2020-111111111111',
  'exercise_incorrect',
  'ex-20h',
  now() - interval '20 hours'
);

SELECT results_eq(
  'SELECT reward_date FROM public.learning_events WHERE id = ''11111111-2020-2020-2020-111111111111''',
  $$SELECT public.local_reward_date(now() - interval '20 hours', 'Asia/Kolkata')$$,
  '29: In-window client_created_at (-20 hours) calculates reward_date from exact -20h timestamp'
);

-- Case C: future client_created_at (+10 days) -> clamped to now()
INSERT INTO public.learning_events (id, event_type, exercise_id, client_created_at)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'exercise_incorrect',
  'ex-future',
  now() + interval '10 days'
);

SELECT results_eq(
  'SELECT reward_date FROM public.learning_events WHERE id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  $$SELECT public.local_reward_date(now(), 'Asia/Kolkata')$$,
  '30: Future client_created_at is clamped to now()'
);

-- Case D: stale client_created_at (-30 days) -> clamped to now() - 48 hours
INSERT INTO public.learning_events (id, event_type, exercise_id, client_created_at)
VALUES (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'exercise_incorrect',
  'ex-stale',
  now() - interval '30 days'
);

SELECT results_eq(
  'SELECT reward_date FROM public.learning_events WHERE id = ''cccccccc-cccc-cccc-cccc-cccccccccccc''',
  $$SELECT public.local_reward_date(now() - interval '48 hours', 'Asia/Kolkata')$$,
  '31: Stale client_created_at older than 48h is clamped to now() - 48 hours'
);

--------------------------------------------------------------------------------
-- 10. Cross-user event read isolation (with positive control)
--------------------------------------------------------------------------------
-- Positive control: Learner 1 can read own event
SELECT results_eq(
  'SELECT user_id FROM public.learning_events WHERE id = ''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa''',
  $$VALUES ('11111111-1111-1111-1111-111111111111'::uuid)$$,
  '32: Positive control: Learner 1 can read own learning event'
);

-- Switch to Learner 2
SET LOCAL "request.jwt.claims" = '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '22222222-2222-2222-2222-222222222222';

SELECT is_empty(
  'SELECT * FROM public.learning_events WHERE id = ''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa''',
  '33: Cross-user learning event read returns zero rows'
);

--------------------------------------------------------------------------------
-- 11. Stable constraint names & daily duplicate exercise rejection
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

SELECT throws_like(
  'INSERT INTO public.learning_events (id, event_type, exercise_id) VALUES (''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'', ''exercise_correct'', ''ex-diff'')',
  '%violates unique constraint "learning_events_pkey"%',
  '34: Retrying identical event id throws 23505 on learning_events_pkey'
);

SELECT throws_like(
  'INSERT INTO public.learning_events (id, event_type, exercise_id) VALUES (gen_random_uuid(), ''exercise_correct'', ''ex-101'')',
  '%violates unique constraint "idx_events_exercise_daily"%',
  '35: Same exercise_correct on same reward_date throws 23505 on idx_events_exercise_daily'
);

-- exercise_incorrect is outside idx_events_exercise_daily
SELECT lives_ok(
  'INSERT INTO public.learning_events (id, event_type, exercise_id) VALUES (gen_random_uuid(), ''exercise_incorrect'', ''ex-101'')',
  '36: exercise_incorrect is outside partial daily index and succeeds'
);

--------------------------------------------------------------------------------
-- 12. Feedback: column grants, check constraints, and cross-user read isolation
--------------------------------------------------------------------------------
SELECT throws_ok(
  'INSERT INTO public.feedback (category, message, status) VALUES (''bug'', ''Cannot submit pre-resolved'', ''resolved'')',
  '42501',
  '37: Inserting explicit status on feedback throws 42501'
);

SELECT throws_ok(
  'INSERT INTO public.feedback (category, message) VALUES (''bug'', ''    '')',
  '23514',
  '38: Whitespace-only feedback message violates check constraint'
);

INSERT INTO public.feedback (id, category, message)
VALUES ('11111111-feed-feed-feed-111111111111', 'bug', 'Audio glitch on lesson greetings');

-- Positive control: Learner 1 can read own feedback
SELECT results_eq(
  'SELECT user_id FROM public.feedback WHERE id = ''11111111-feed-feed-feed-111111111111''',
  $$VALUES ('11111111-1111-1111-1111-111111111111'::uuid)$$,
  '39: Positive control: Learner 1 can read own feedback'
);

-- Learner 2 cannot read Learner 1 feedback
SET LOCAL "request.jwt.claims" = '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '22222222-2222-2222-2222-222222222222';

SELECT is_empty(
  'SELECT * FROM public.feedback WHERE user_id = ''11111111-1111-1111-1111-111111111111''',
  '40: Cross-user feedback read returns zero rows'
);

--------------------------------------------------------------------------------
-- 13. Timezone change behavior: historical reward_date intact, new events use new zone
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

UPDATE public.profiles
SET timezone = 'Pacific/Auckland'
WHERE id = '11111111-1111-1111-1111-111111111111';

SELECT results_eq(
  'SELECT reward_date FROM public.learning_events WHERE id = ''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa''',
  $$SELECT public.local_reward_date(now(), 'Asia/Kolkata')$$,
  '41: Timezone update on profile does not alter historical event reward_date'
);

INSERT INTO public.learning_events (id, event_type, exercise_id)
VALUES (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'exercise_incorrect',
  'ex-auckland'
);

SELECT results_eq(
  'SELECT reward_date FROM public.learning_events WHERE id = ''dddddddd-dddd-dddd-dddd-dddddddddddd''',
  $$SELECT public.local_reward_date(now(), 'Pacific/Auckland')$$,
  '42: New event inserted after timezone update uses new Pacific/Auckland timezone'
);

--------------------------------------------------------------------------------
-- 14. Non-admin and inactive admin RPC restrictions
--------------------------------------------------------------------------------
SELECT throws_like(
  'SELECT public.admin_set_user_active(''22222222-2222-2222-2222-222222222222'', false)',
  '%Access denied: caller is not an active administrator.%',
  '43: Learner calling admin_set_user_active throws access denied'
);

SELECT throws_like(
  'SELECT public.admin_set_feedback_status(gen_random_uuid(), ''resolved'')',
  '%Access denied: caller is not an active administrator.%',
  '44: Learner calling admin_set_feedback_status throws access denied'
);

SELECT throws_like(
  'SELECT public.get_admin_learner_summary(''22222222-2222-2222-2222-222222222222'')',
  '%Access denied: caller is not an active administrator.%',
  '45: Learner calling get_admin_learner_summary throws access denied'
);

-- Inactive admin cannot call any admin RPC
SET LOCAL "request.jwt.claims" = '{"sub": "55555555-5555-5555-5555-555555555555", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '55555555-5555-5555-5555-555555555555';

SELECT throws_like(
  'SELECT public.admin_set_user_active(''22222222-2222-2222-2222-222222222222'', false)',
  '%Access denied: caller is not an active administrator.%',
  '46: Inactive admin calling admin_set_user_active throws access denied'
);

SELECT throws_like(
  'SELECT public.admin_set_feedback_status(gen_random_uuid(), ''resolved'')',
  '%Access denied: caller is not an active administrator.%',
  '47: Inactive admin calling admin_set_feedback_status throws access denied'
);

SELECT throws_like(
  'SELECT public.get_admin_learner_summary(''11111111-1111-1111-1111-111111111111'')',
  '%Access denied: caller is not an active administrator.%',
  '48: Inactive admin calling get_admin_learner_summary throws access denied'
);

--------------------------------------------------------------------------------
-- 15. Admin capabilities & security boundaries
--------------------------------------------------------------------------------
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '33333333-3333-3333-3333-333333333333';

-- Positive control: Admin identity confirmed
SELECT results_eq(
  'SELECT role FROM public.profiles WHERE id = (SELECT auth.uid())',
  $$VALUES ('admin'::text)$$,
  '49: Positive control: Admin user confirms admin role'
);

-- Admin cannot select raw learning_events (RLS restricts to user_id = auth.uid())
SELECT is_empty(
  'SELECT * FROM public.learning_events WHERE user_id = ''11111111-1111-1111-1111-111111111111''',
  '50: Admin cannot select raw learning events of other users'
);

-- Admin cannot directly UPDATE profiles.is_active or feedback.status (42501)
SELECT throws_ok(
  'UPDATE public.profiles SET is_active = false WHERE id = ''22222222-2222-2222-2222-222222222222''',
  '42501',
  '51: Admin direct update on profiles.is_active throws 42501 (must use RPC)'
);

SELECT throws_ok(
  'UPDATE public.feedback SET status = ''resolved'' WHERE id = ''11111111-feed-feed-feed-111111111111''',
  '42501',
  '52: Admin direct update on feedback.status throws 42501 (must use RPC)'
);

-- Admin reads all feedback via RLS (using cmp_ok >= 1)
SELECT cmp_ok(
  (SELECT count(*)::integer FROM public.feedback),
  '>=',
  1,
  '53: Admin can read all feedback via RLS policy'
);

-- Admin calls admin_set_feedback_status on real feedback row and verifies with privileged read
SELECT lives_ok(
  'SELECT public.admin_set_feedback_status(''11111111-feed-feed-feed-111111111111'', ''read'')',
  '54: Admin successfully calls admin_set_feedback_status on real feedback'
);

-- Privileged check: verify status updated
RESET ROLE;
SELECT results_eq(
  'SELECT status FROM public.feedback WHERE id = ''11111111-feed-feed-feed-111111111111''',
  $$VALUES ('read'::text)$$,
  '55: Privileged verification: feedback status was updated to read'
);

-- Admin calls admin_set_user_active on Learner 2 and verifies with privileged read
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '33333333-3333-3333-3333-333333333333';

SELECT lives_ok(
  'SELECT public.admin_set_user_active(''22222222-2222-2222-2222-222222222222'', false)',
  '56: Admin successfully calls admin_set_user_active to deactivate Learner 2'
);

-- Privileged check: verify Learner 2 is_active = false
RESET ROLE;
SELECT results_eq(
  'SELECT is_active FROM public.profiles WHERE id = ''22222222-2222-2222-2222-222222222222''',
  $$VALUES (false)$$,
  '57: Privileged verification: Learner 2 is_active is now false'
);

-- Admin self-deactivation rejected via RPC
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
SET LOCAL "request.jwt.claim.sub" = '33333333-3333-3333-3333-333333333333';

SELECT throws_like(
  'SELECT public.admin_set_user_active(''33333333-3333-3333-3333-333333333333'', false)',
  '%administrators cannot deactivate their own account%',
  '58: Active admin cannot deactivate self'
);

--------------------------------------------------------------------------------
-- 16. Dedicated Streak Test Cases A-E and XP Cap Test
--------------------------------------------------------------------------------
-- Case A: today, -1, -2 => streak = 3, XP = 150 (3 * 50)
SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''aaaaaaaa-0000-0000-0000-aaaaaaaaaaaa'')->>''current_day_streak'')::integer',
  $$VALUES (3)$$,
  '59: Streak Case A (today, -1, -2) returns current_day_streak = 3'
);
SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''aaaaaaaa-0000-0000-0000-aaaaaaaaaaaa'')->>''server_derived_xp'')::integer',
  $$VALUES (150)$$,
  '60: Streak Case A calculates 150 server_derived_xp'
);

-- Case B: -1, -2 => streak = 2 (ended yesterday), XP = 100
SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''bbbbbbbb-0000-0000-0000-bbbbbbbbbbbb'')->>''current_day_streak'')::integer',
  $$VALUES (2)$$,
  '61: Streak Case B (-1, -2, ended yesterday) returns current_day_streak = 2'
);
SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''bbbbbbbb-0000-0000-0000-bbbbbbbbbbbb'')->>''server_derived_xp'')::integer',
  $$VALUES (100)$$,
  '62: Streak Case B calculates 100 server_derived_xp'
);

-- Case C: today, -2 => streak = 1 (gap on -1 breaks run)
SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''cccccccc-0000-0000-0000-cccccccccccc'')->>''current_day_streak'')::integer',
  $$VALUES (1)$$,
  '63: Streak Case C (today, -2 with gap) returns current_day_streak = 1'
);

-- Case D: -2, -3 => streak = 0 (ended two days ago)
SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''dddddddd-0000-0000-0000-dddddddddddd'')->>''current_day_streak'')::integer',
  $$VALUES (0)$$,
  '64: Streak Case D (-2, -3, ended two days ago) returns current_day_streak = 0'
);

-- Case E: -1 incorrect-only plus -2 lesson => streak = 2, XP = 50 (incorrect gives 0 XP)
SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''eeeeeeee-0000-0000-0000-eeeeeeeeeeee'')->>''current_day_streak'')::integer',
  $$VALUES (2)$$,
  '65: Streak Case E (-1 incorrect-only + -2 lesson) returns current_day_streak = 2'
);
SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''eeeeeeee-0000-0000-0000-eeeeeeeeeeee'')->>''server_derived_xp'')::integer',
  $$VALUES (50)$$,
  '66: Streak Case E calculates 50 server_derived_xp (incorrect-only day adds 0 XP)'
);

-- User 2 XP-Cap Fixture: 250 raw XP on T-2 capped to 200 + 0 on T-1 + 50 on T = 250 XP; streak = 3
SELECT results_eq(
  'SELECT (public.get_admin_learner_summary(''22222222-2222-2222-2222-222222222222'')->>''server_derived_xp'')::integer',
  $$VALUES (250)$$,
  '67: Daily 200 XP cap respected: 250 raw XP on T-2 capped to 200 + 0 on T-1 + 50 on T = 250 XP'
);

SELECT * FROM finish();
ROLLBACK;
