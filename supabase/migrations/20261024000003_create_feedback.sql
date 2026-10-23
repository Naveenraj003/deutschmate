-- Migration 00003: Create feedback table and RLS policies
-- Description: Bug reports, content mistake corrections, and user suggestions.

-- 1. Create table
CREATE TABLE IF NOT EXISTS public.feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  category text NOT NULL,
  message text NOT NULL,
  lesson_id text,
  exercise_id text,
  status text NOT NULL DEFAULT 'new',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT check_feedback_category CHECK (
    category IN ('bug', 'content_mistake', 'suggestion')
  ),
  CONSTRAINT check_feedback_message_length CHECK (
    char_length(trim(message)) >= 5 AND char_length(message) <= 2000
  ),
  CONSTRAINT check_feedback_lesson_id_length CHECK (
    lesson_id IS NULL OR (char_length(lesson_id) BETWEEN 1 AND 64)
  ),
  CONSTRAINT check_feedback_exercise_id_length CHECK (
    exercise_id IS NULL OR (char_length(exercise_id) BETWEEN 1 AND 64)
  ),
  CONSTRAINT check_feedback_status_valid CHECK (
    status IN ('new', 'read', 'resolved')
  )
);

-- 2. Indexes for queries
CREATE INDEX IF NOT EXISTS idx_feedback_user_id ON public.feedback (user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_status_created_at ON public.feedback (status, created_at DESC);

-- 3. Enable RLS
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

-- 4. Revoke broad privileges and configure permissions
REVOKE ALL ON TABLE public.feedback FROM anon, PUBLIC;
REVOKE ALL ON TABLE public.feedback FROM authenticated;

-- Grant SELECT and INSERT only to authenticated
-- No direct UPDATE is granted to authenticated; status changes MUST go through admin_set_feedback_status RPC.
GRANT SELECT, INSERT ON TABLE public.feedback TO authenticated;

-- 5. RLS Policies
-- Learners may view their own feedback; Admins may view all feedback
CREATE POLICY "feedback_select"
  ON public.feedback
  FOR SELECT
  TO authenticated
  USING (
    ((SELECT auth.uid()) = user_id AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND is_active = true
    ))
    OR public.is_admin()
  );

-- Learners may insert feedback with default status 'new' while active
CREATE POLICY "feedback_insert_own"
  ON public.feedback
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND status = 'new'
    AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND is_active = true
    )
  );
