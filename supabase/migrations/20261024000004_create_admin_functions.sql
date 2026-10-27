-- Migration 00004: Admin RPCs and server-derived aggregate functions
-- Description: SECURITY DEFINER operations for admin user management, feedback status, and progress reporting using reward_date.

-- 1. admin_set_user_active
-- Toggles learner active status. Rejects self-deactivation and non-admin calls.
CREATE OR REPLACE FUNCTION public.admin_set_user_active(
  target_user_id uuid,
  new_active boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid;
  v_target_role text;
BEGIN
  v_caller_id := (SELECT auth.uid());

  -- 1. Check admin authorization (must be active admin)
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: caller is not an active administrator.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Reject self-deactivation
  IF v_caller_id = target_user_id AND new_active = false THEN
    RAISE EXCEPTION 'Operation rejected: administrators cannot deactivate their own account.'
      USING ERRCODE = '22023';
  END IF;

  -- 3. Verify target exists
  SELECT role INTO v_target_role
  FROM public.profiles
  WHERE id = target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Target user profile not found for id %', target_user_id
      USING ERRCODE = '02000';
  END IF;

  -- 4. Execute update
  UPDATE public.profiles
  SET is_active = new_active
  WHERE id = target_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', target_user_id,
    'is_active', new_active
  );
END;
$$;

-- 2. admin_set_feedback_status
-- Modifies feedback status strictly to 'new', 'read', or 'resolved'.
CREATE OR REPLACE FUNCTION public.admin_set_feedback_status(
  target_feedback_id uuid,
  new_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- 1. Check admin authorization (must be active admin)
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: caller is not an active administrator.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Validate input status
  IF new_status NOT IN ('new', 'read', 'resolved') THEN
    RAISE EXCEPTION 'Invalid status value: %. Permitted values: new, read, resolved.', new_status
      USING ERRCODE = '22023';
  END IF;

  -- 3. Execute update
  UPDATE public.feedback
  SET status = new_status
  WHERE id = target_feedback_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Feedback record not found for id %', target_feedback_id
      USING ERRCODE = '02000';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'feedback_id', target_feedback_id,
    'status', new_status
  );
END;
$$;

-- 3. get_admin_learner_summary
-- Server-derived aggregate analytics.
-- Rules:
--  - Derived from learning_events using stored reward_date and server created_at.
--  - Client-supplied XP ignored; server applies exact rules:
--      * lesson_completed = 50 XP
--      * exercise_correct = 10 XP (at most once per exercise per reward_date)
--      * review_correct = 5 XP
--      * exercise_incorrect = 0 XP
--      * Daily XP cap = 200 XP per reward_date.
--  - Streak calculation:
--      * Counts consecutive calendar days with at least one eligible event:
--        ('lesson_completed', 'exercise_correct', 'review_correct', 'exercise_incorrect').
--      * Days containing ONLY exercise_incorrect maintain the streak (0 XP earned).
--      * Group consecutive dates by (reward_date - row_number):
--        The current streak is the run ending today or yesterday (relative to user's current timezone).
--      * Note: a later timezone change can shift today's boundary once, but historical reward_date is immutable.
CREATE OR REPLACE FUNCTION public.get_admin_learner_summary(
  target_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_tz text;
  v_last_active timestamptz;
  v_total_xp integer := 0;
  v_current_streak integer := 0;
  v_events_count bigint := 0;
  v_today date;
  v_yesterday date;
BEGIN
  -- 1. Verify caller is active admin
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: caller is not an active administrator.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Look up learner timezone and existence
  SELECT timezone INTO v_user_tz
  FROM public.profiles
  WHERE id = target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile not found for id %', target_user_id
      USING ERRCODE = '02000';
  END IF;

  IF v_user_tz IS NULL OR v_user_tz = '' THEN
    v_user_tz := 'UTC';
  END IF;

  -- 3. Determine last active timestamp and total events count
  SELECT
    MAX(created_at),
    COUNT(*)
  INTO
    v_last_active,
    v_events_count
  FROM public.learning_events
  WHERE user_id = target_user_id;

  -- 4. Calculate Server-Derived XP with Daily Cap (200 XP / reward_date)
  WITH daily_raw_events AS (
    SELECT
      reward_date,
      CASE
        WHEN event_type = 'lesson_completed' THEN 50
        WHEN event_type = 'exercise_correct' THEN 10
        WHEN event_type = 'review_correct' THEN 5
        WHEN event_type = 'exercise_incorrect' THEN 0
        ELSE 0
      END AS event_xp
    FROM public.learning_events
    WHERE user_id = target_user_id
  ),
  daily_capped_xp AS (
    SELECT
      reward_date,
      LEAST(200, SUM(event_xp)) AS day_xp
    FROM daily_raw_events
    GROUP BY reward_date
  )
  SELECT COALESCE(SUM(day_xp), 0)::integer
  INTO v_total_xp
  FROM daily_capped_xp;

  -- 5. Calculate Consecutive Streak Days using (reward_date - row_number)
  -- Eligible streak events explicitly encode: lesson_completed, exercise_correct, review_correct, exercise_incorrect
  v_today := (now() AT TIME ZONE v_user_tz)::date;
  v_yesterday := v_today - 1;

  WITH active_dates AS (
    SELECT DISTINCT reward_date
    FROM public.learning_events
    WHERE user_id = target_user_id
      AND event_type IN ('lesson_completed', 'exercise_correct', 'review_correct', 'exercise_incorrect')
  ),
  grouped_dates AS (
    SELECT
      reward_date,
      (reward_date - (row_number() OVER (ORDER BY reward_date))::integer) AS grp
    FROM active_dates
  ),
  streak_runs AS (
    SELECT
      grp,
      COUNT(*)::integer AS streak_length,
      MAX(reward_date) AS end_date
    FROM grouped_dates
    GROUP BY grp
  )
  SELECT COALESCE(streak_length, 0)
  INTO v_current_streak
  FROM streak_runs
  WHERE end_date IN (v_today, v_yesterday)
  ORDER BY end_date DESC
  LIMIT 1;

  -- 6. Return Structured Summary
  RETURN jsonb_build_object(
    'user_id', target_user_id,
    'total_reported_events', v_events_count,
    'server_derived_xp', v_total_xp,
    'current_day_streak', COALESCE(v_current_streak, 0),
    'last_active_at', v_last_active,
    'learner_timezone', v_user_tz,
    'metrics_notice', 'Reported activity: exercise and lesson completions are recorded client-side and aggregated server-side under daily caps.'
  );
END;
$$;

-- 4. Configure Privileges
REVOKE ALL ON FUNCTION public.admin_set_user_active(uuid, boolean) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_feedback_status(uuid, text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.get_admin_learner_summary(uuid) FROM anon, PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_set_user_active(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_feedback_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_learner_summary(uuid) TO authenticated;
