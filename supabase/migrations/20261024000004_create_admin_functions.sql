-- Migration 00004: Admin RPCs and server-derived aggregate functions
-- Description: SECURITY DEFINER operations for admin user management, feedback status, and progress reporting.

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

  -- 1. Check admin authorization
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
  -- 1. Check admin authorization
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
--  - Derived from learning_events using server created_at only (client_created_at ignored).
--  - Client-supplied XP ignored; server applies exact rules:
--      * lesson_completed = 50 XP
--      * exercise_correct = 10 XP (at most once per exercise per UTC day)
--      * review_correct = 5 XP
--      * Daily XP cap = 200 XP per calendar day in user's timezone.
--  - Streak = consecutive local calendar days containing >= 1 eligible event, anchored to today/yesterday.
--  - Self-reported caveat documented in payload metadata.
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
  v_today_date date;
  v_yesterday_date date;
BEGIN
  -- 1. Verify caller is admin
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

  -- Default to UTC if invalid or missing
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

  -- 4. Calculate Server-Derived XP with Daily Cap (200 XP / day in user timezone)
  WITH daily_raw_events AS (
    SELECT
      (created_at AT TIME ZONE v_user_tz)::date AS local_date,
      CASE
        WHEN event_type = 'lesson_completed' THEN 50
        WHEN event_type = 'exercise_correct' THEN 10
        WHEN event_type = 'review_correct' THEN 5
        ELSE 0
      END AS event_xp
    FROM public.learning_events
    WHERE user_id = target_user_id
  ),
  daily_capped_xp AS (
    SELECT
      local_date,
      LEAST(200, SUM(event_xp)) AS day_xp
    FROM daily_raw_events
    GROUP BY local_date
  )
  SELECT COALESCE(SUM(day_xp), 0)::integer
  INTO v_total_xp
  FROM daily_capped_xp;

  -- 5. Calculate Consecutive Streak Days
  v_today_date := (now() AT TIME ZONE v_user_tz)::date;
  v_yesterday_date := v_today_date - 1;

  WITH active_days AS (
    SELECT DISTINCT (created_at AT TIME ZONE v_user_tz)::date AS act_date
    FROM public.learning_events
    WHERE user_id = target_user_id
  ),
  numbered_days AS (
    SELECT
      act_date,
      row_number() OVER (ORDER BY act_date DESC) AS rn,
      act_date + (row_number() OVER (ORDER BY act_date DESC) * INTERVAL '1 day') AS grp
    FROM active_days
  ),
  streak_group AS (
    -- Streak must include today or yesterday to be active
    SELECT grp, COUNT(*) AS len
    FROM numbered_days
    WHERE act_date >= v_yesterday_date
    GROUP BY grp
    LIMIT 1
  )
  SELECT COALESCE(len, 0)::integer
  INTO v_current_streak
  FROM streak_group;

  -- 6. Return Structured Summary
  RETURN jsonb_build_object(
    'user_id', target_user_id,
    'total_reported_events', v_events_count,
    'server_derived_xp', v_total_xp,
    'current_day_streak', v_current_streak,
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
