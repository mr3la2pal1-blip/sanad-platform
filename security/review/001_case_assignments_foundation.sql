-- SANAD SECURITY REVIEW DRAFT — NOT APPROVED FOR PRODUCTION EXECUTION
-- This migration is intentionally staged. It creates ONLY the assignment foundation.
-- It does NOT replace existing policies on business tables. Do not run until reviewed.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.profiles') IS NULL OR to_regclass('public.family_cases') IS NULL THEN
    RAISE EXCEPTION 'Required reviewed tables are missing; stop.';
  END IF;
  IF to_regclass('public.case_assignments') IS NOT NULL THEN
    RAISE EXCEPTION 'case_assignments already exists; inspect it before proceeding.';
  END IF;
END $$;

CREATE TABLE public.case_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES public.family_cases(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  assignment_role text NOT NULL
    CHECK (assignment_role IN ('researcher','orphan_supervisor','distributor')),
  assigned_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  notes text,
  CHECK (ended_at IS NULL OR ended_at >= assigned_at)
);

CREATE UNIQUE INDEX case_assignments_one_active_user_role
  ON public.case_assignments(case_id,user_id,assignment_role)
  WHERE is_active = true;
CREATE INDEX case_assignments_active_user_role_case
  ON public.case_assignments(user_id,assignment_role,case_id)
  WHERE is_active = true;

ALTER TABLE public.case_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY case_assignments_admin_select
ON public.case_assignments FOR SELECT TO authenticated
USING (private.current_app_role() = 'admin');

CREATE POLICY case_assignments_admin_insert
ON public.case_assignments FOR INSERT TO authenticated
WITH CHECK (
  private.current_app_role() = 'admin'
  AND (assigned_by IS NULL OR assigned_by = (SELECT auth.uid()))
);

CREATE POLICY case_assignments_admin_update
ON public.case_assignments FOR UPDATE TO authenticated
USING (private.current_app_role() = 'admin')
WITH CHECK (private.current_app_role() = 'admin');

CREATE POLICY case_assignments_admin_delete
ON public.case_assignments FOR DELETE TO authenticated
USING (private.current_app_role() = 'admin');

CREATE POLICY case_assignments_self_select
ON public.case_assignments FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()) AND is_active = true);

REVOKE ALL ON TABLE public.case_assignments FROM anon;
REVOKE ALL ON TABLE public.case_assignments FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.case_assignments TO authenticated;

-- SECURITY DEFINER is narrowly scoped to an existence check.
CREATE OR REPLACE FUNCTION private.has_case_assignment(
  p_case_id uuid,
  p_assignment_role text DEFAULT NULL
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
SET row_security TO 'off'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.case_assignments AS ca
    JOIN public.profiles AS p ON p.id = ca.user_id
    WHERE ca.case_id = p_case_id
      AND ca.user_id = (SELECT auth.uid())
      AND ca.is_active = true
      AND p.is_active = true
      AND (p_assignment_role IS NULL OR ca.assignment_role = p_assignment_role)
  );
$function$;

REVOKE ALL ON FUNCTION private.has_case_assignment(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.has_case_assignment(uuid,text) TO authenticated;

COMMIT;

-- REQUIRED BEFORE PRODUCTION:
-- 1. Add role-to-assignment validation (target profile role must match assignment_role).
-- 2. Decide if orphan-supervisor assignment is case-level or orphan-level.
-- 3. Replace existing permissive policies on family_cases, case_private_details,
--    orphan_profiles, assistance_requests, distribution_records, sponsorships,
--    tasks and complaints; do not simply add parallel permissive policies (OR semantics).
-- 4. Decide complaint ownership; reviewed schema did not show a submitter/user_id column.
-- 5. Decide exactly which financial columns accountants need and hide them from orphan supervisors.
-- 6. Test each role using real authenticated sessions before production.
-- 7. This file is a review artifact, not a ready-to-run production migration.
