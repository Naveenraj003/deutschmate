-- Migration 00002: Create learning_events table and RLS policies
-- Description: Client-generated idempotent append-only telemetry stream for self-reported progress.

-- 1. Create table
CREATE TABLE IF NOT EXISTS public.learning_events (
  id uuid PRIMARY KEY, -- Client-generated idempotency key
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  lesson_id text,
  exercise_id text,
  word_id text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  client_created_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT check_event_type_allowlist CHECK (
    event_type IN ('lesson_completed', 'exercise_correct', 'review_correct')
  ),
  CONSTRAINT check_lesson_id_length CHECK (
    lesson_id IS NULL OR (char_length(lesson_id) BETWEEN 1 AND 64)
  ),
  CONSTRAINT check_exercise_id_length CHECK (
    exercise_id IS NULL OR (char_length(exercise_id) BETWEEN 1 AND 64)
  ),
  CONSTRAINT check_word_id_length CHECK (
    word_id IS NULL OR (char_length(word_id) BETWEEN 1 AND 64)
  ),
  CONSTRAINT check_payload_size CHECK (
    octet_length(payload::text) <= 8192 -- Max 8KB
  )
);

-- 2. Concurrency-safe unique constraint to prevent duplicate exercise XP on same server UTC day
CREATE UNIQUE INDEX IF NOT EXISTS idx_learning_events_exercise_daily_unique
  ON public.learning_events (user_id, exercise_id, ((created_at AT TIME ZONE 'UTC')::date))
  WHERE event_type = 'exercise_correct' AND exercise_id IS NOT NULL;

-- 3. Query index for user timeline queries
CREATE INDEX IF NOT EXISTS idx_learning_events_user_created_at
  ON public.learning_events (user_id, created_at DESC);

-- 4. Enable RLS
ALTER TABLE public.learning_events ENABLE ROW LEVEL SECURITY;

-- 5. Revoke broad privileges and configure permissions
REVOKE ALL ON TABLE public.learning_events FROM anon, PUBLIC;
REVOKE ALL ON TABLE public.learning_events FROM authenticated;

-- Grant only SELECT and INSERT (Append-only: No UPDATE, No DELETE)
GRANT SELECT, INSERT ON TABLE public.learning_events TO authenticated;

-- 6. RLS Policies
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

-- Note: No UPDATE or DELETE policies are defined, preventing any record modification.
