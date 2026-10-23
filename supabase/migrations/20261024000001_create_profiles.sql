-- Migration 00001: Create profiles table, signup trigger, and RLS policies
-- Description: Establishes learner profiles mapped 1:1 to auth.users, column privileges, and security boundaries.

-- 1. Create table
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text,
  teaching_language text NOT NULL DEFAULT 'tamil',
  role text NOT NULL DEFAULT 'learner',
  timezone text NOT NULL DEFAULT 'UTC',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT check_display_name_length CHECK (display_name IS NULL OR char_length(display_name) <= 100),
  CONSTRAINT check_teaching_language_valid CHECK (teaching_language IN ('english', 'tamil')),
  CONSTRAINT check_role_valid CHECK (role IN ('learner', 'admin')),
  CONSTRAINT check_timezone_length CHECK (char_length(timezone) <= 64)
);

-- 2. Create updated_at trigger helper
CREATE OR REPLACE FUNCTION public.set_current_timestamp_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- 3. is_admin() helper function
-- Must be STABLE SECURITY DEFINER with fixed empty search_path
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND role = 'admin'
      AND is_active = true
  );
$$;

-- 4. Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 5. Revoke broad permissions and configure column-level security
REVOKE ALL ON TABLE public.profiles FROM anon, PUBLIC;
REVOKE ALL ON TABLE public.profiles FROM authenticated;

-- Allow authenticated users to SELECT records allowed by RLS
GRANT SELECT ON TABLE public.profiles TO authenticated;

-- Column-level update restriction: learners may update only display_name, teaching_language, and timezone.
-- Updates to role, is_active, id, or created_at fail with a permission error.
GRANT UPDATE (display_name, teaching_language, timezone) ON TABLE public.profiles TO authenticated;

-- 6. RLS Policies for profiles
-- Learners can view their own profile only if active
CREATE POLICY "profiles_select_own"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    (SELECT auth.uid()) = id AND is_active = true
  );

-- Admins can view all profiles
CREATE POLICY "profiles_select_admin"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    public.is_admin()
  );

-- Learners can update their own profile while active
CREATE POLICY "profiles_update_own"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (
    (SELECT auth.uid()) = id AND is_active = true
  )
  WITH CHECK (
    (SELECT auth.uid()) = id AND is_active = true
  );

-- 7. Signup trigger to create profile
-- Always forces role = 'learner' and is_active = true, ignoring any client-provided role or status.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_raw_lang text;
  v_lang text;
  v_display_name text;
BEGIN
  -- Extract and sanitize teaching_language metadata
  v_raw_lang := lower(trim(COALESCE(NEW.raw_user_meta_data->>'teaching_language', 'tamil')));
  IF v_raw_lang IN ('english', 'tamil') THEN
    v_lang := v_raw_lang;
  ELSE
    v_lang := 'tamil';
  END IF;

  -- Extract display name with truncation limit
  v_display_name := NULLIF(trim(NEW.raw_user_meta_data->>'display_name'), '');
  IF v_display_name IS NOT NULL AND char_length(v_display_name) > 100 THEN
    v_display_name := substring(v_display_name FROM 1 FOR 100);
  END IF;

  INSERT INTO public.profiles (
    id,
    display_name,
    teaching_language,
    role,
    timezone,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    v_display_name,
    v_lang,
    'learner',     -- Hardcoded security default
    'UTC',
    true,          -- Hardcoded security default
    now(),
    now()
  );

  RETURN NEW;
END;
$$;

-- Create auth trigger (on auth.users table)
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Revoke execute on trigger and internal functions
REVOKE ALL ON FUNCTION public.handle_new_user() FROM anon, authenticated, PUBLIC;
REVOKE ALL ON FUNCTION public.set_current_timestamp_updated_at() FROM anon, authenticated, PUBLIC;
REVOKE ALL ON FUNCTION public.is_admin() FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
