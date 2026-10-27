-- Migration 00002: Create learning_events table and RLS policies
-- Description: Client-generated idempotent append-only telemetry stream for self-reported progress.

-- 1. Create table with reward_date NOT NULL
CREATE TABLE IF NOT EXISTS public.learning_events (
  id uuid PRIMARY KEY, -- Client-generated idempotency key (learning_events_pkey)
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  lesson_id text,
  exercise_id text,
  word_id text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  client_created_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  reward_date date NOT NULL,
  CONSTRAINT check_event_type_allowlist CHECK (
    event_type IN ('lesson_completed', 'exercise_correct', 'review_correct', 'exercise_incorrect')
  ),
  -- Split constraint (a): exercise_id format for all event types
  CONSTRAINT check_exercise_id_format CHECK (
    exercise_id IS NULL OR (char_length(exercise_id) BETWEEN 1 AND 64)
  ),
  -- Split constraint (b): exercise_correct and exercise_incorrect require exercise_id IS NOT NULL
  CONSTRAINT check_exercise_events_require_exercise_id CHECK (
    (event_type IN ('exercise_correct', 'exercise_incorrect') AND exercise_id IS NOT NULL)
    OR (event_type NOT IN ('exercise_correct', 'exercise_incorrect'))
  ),
  CONSTRAINT check_lesson_id_length CHECK (
    lesson_id IS NULL OR (char_length(lesson_id) BETWEEN 1 AND 64)
  ),
  CONSTRAINT check_word_id_length CHECK (
    word_id IS NULL OR (char_length(word_id) BETWEEN 1 AND 64)
  ),
  CONSTRAINT check_payload_size CHECK (
    octet_length(payload::text) <= 8192 -- Max 8KB
  )
);

-- 2. BEFORE INSERT trigger helper: server timestamps, user timezone lookup, 48h clamp, no UTC fallback
CREATE OR REPLACE FUNCTION public.set_learning_event_server_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_tz text;
  v_event_ts timestamptz;
BEGIN
  -- Force authoritative user_id from auth.uid() if not already set or defaulted
  IF NEW.user_id IS NULL THEN
    NEW.user_id := (SELECT auth.uid());
  END IF;

  -- Lookup user timezone from public.profiles
  SELECT timezone INTO v_tz
  FROM public.profiles
  WHERE id = NEW.user_id;

  -- Raise exception if no profile exists (NO UTC fallback)
  IF NOT FOUND OR v_tz IS NULL THEN
    RAISE EXCEPTION 'No profile found for user %: cannot resolve timezone for learning event', NEW.user_id
      USING ERRCODE = 'P0002';
  END IF;

  -- Clamp client_created_at between now() - 48 hours and now()
  v_event_ts := LEAST(now(), GREATEST(COALESCE(NEW.client_created_at, now()), now() - interval '48 hours'));

  -- Always set created_at and reward_date authoritatively on the server using local_reward_date
  NEW.created_at := now();
  NEW.reward_date := public.local_reward_date(v_event_ts, v_tz);

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_learning_events_set_server_fields
BEFORE INSERT ON public.learning_events
FOR EACH ROW
EXECUTE FUNCTION public.set_learning_event_server_fields();

-- 3. Concurrency-safe unique index with stable name idx_events_exercise_daily
-- exercise_incorrect is outside this index (WHERE event_type = 'exercise_correct')
CREATE UNIQUE INDEX IF NOT EXISTS idx_events_exercise_daily
  ON public.learning_events (user_id, exercise_id, reward_date)
  WHERE event_type = 'exercise_correct';

-- 4. Query indexes
CREATE INDEX IF NOT EXISTS idx_learning_events_user_reward_date
  ON public.learning_events (user_id, reward_date DESC);

CREATE INDEX IF NOT EXISTS idx_learning_events_user_created_at
  ON public.learning_events (user_id, created_at DESC);

-- 5. Enable RLS
ALTER TABLE public.learning_events ENABLE ROW LEVEL SECURITY;

-- 6. Revoke broad privileges and configure permissions
REVOKE ALL ON TABLE public.learning_events FROM anon, PUBLIC;
REVOKE ALL ON TABLE public.learning_events FROM authenticated;

-- Allow authenticated users to SELECT records allowed by RLS
GRANT SELECT ON TABLE public.learning_events TO authenticated;

-- Grant INSERT ONLY on client-settable columns (created_at, reward_date, user_id are server-managed)
GRANT INSERT (id, event_type, lesson_id, exercise_id, word_id, payload, client_created_at)
  ON TABLE public.learning_events TO authenticated;

-- Note: No UPDATE or DELETE is granted to authenticated or anon, causing 42501 permission error on mutation attempts.

-- 7. RLS Policies
-- Learners may read their own events only while active
CREATE POLICY "learning_events_select_own"
  ON public.learning_events
  FOR SELECT
  TO authenticated
  USING (
    (SELECT auth.uid()) = user_id
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = (SELECT auth.uid()) AND is_active = true
    )
  );

-- Learners may insert events only for themselves while active
CREATE POLICY "learning_events_insert_own"
  ON public.learning_events
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = (SELECT auth.uid()) AND is_active = true
    )
  );

-- Revoke execute on internal trigger
REVOKE ALL ON FUNCTION public.set_learning_event_server_fields() FROM anon, authenticated, PUBLIC;
