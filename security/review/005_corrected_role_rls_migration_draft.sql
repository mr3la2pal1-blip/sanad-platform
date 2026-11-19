-- SANAD SECURITY HARDENING — REVIEW DRAFT ONLY
-- DO NOT RUN IN PRODUCTION.
-- This file is a proposed migration for review. It has NOT been executed.
-- It replaces known permissive policies, so execution changes staff access.
-- Preconditions: take a backup; test in staging; review the role/column matrix.
--
-- Important known limitation:
-- RLS is row-level and cannot hide sponsorship/donation columns from orphan
-- supervisors while allowing accountants to read those same rows. A separate
-- view/API + base-table privilege design is required before financial-column
-- isolation can be claimed. This migration intentionally does NOT change
-- existing table grants or default privileges.
--
-- Complaint limitation:
-- complaints has assigned_to but no confirmed submitter/created_by field.
-- This draft keeps complaint SELECT limited to admin/assignee and preserves
-- authenticated INSERT. It does not create a self-read policy for submitters.

BEGIN;

-- Fail closed if the reviewed schema has drifted.
DO $preflight$
DECLARE
  required_table text;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'profiles','family_cases','case_private_details','orphan_profiles',
    'sponsorships','assistance_requests','distribution_records','tasks',
    'audit_logs','complaints','volunteers','donations','announcements',
    'campaigns','public_aid_intake'
  ] LOOP
    IF to_regclass('public.' || required_table) IS NULL THEN
      RAISE EXCEPTION 'Required table public.% is missing; aborting.', required_table;
    END IF;
  END LOOP;

  IF to_regclass('public.case_assignments') IS NOT NULL
     OR to_regclass('public.orphan_assignments') IS NOT NULL THEN
    RAISE EXCEPTION 'An assignment table already exists. Inspect it and reconcile manually; do not rerun this draft.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='family_cases'
      AND column_name='assigned_researcher'
  ) THEN
    RAISE EXCEPTION 'Expected family_cases.assigned_researcher column missing; schema drift.';
  END IF;
END
$preflight$;

-- Assignment tables retain history. Normal reassignment ends an assignment;
-- it does not delete the historical row.
CREATE TABLE public.case_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES public.family_cases(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  assignment_role text NOT NULL CHECK (assignment_role IN ('researcher','distributor')),
  assigned_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  notes text,
  CHECK (ended_at IS NULL OR ended_at >= assigned_at)
);

CREATE UNIQUE INDEX case_assignments_one_active
  ON public.case_assignments(case_id,user_id,assignment_role)
  WHERE is_active;
CREATE INDEX case_assignments_user_role_active
  ON public.case_assignments(user_id,assignment_role,case_id)
  WHERE is_active;

CREATE TABLE public.orphan_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  orphan_id uuid NOT NULL REFERENCES public.orphan_profiles(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  assigned_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  notes text,
  CHECK (ended_at IS NULL OR ended_at >= assigned_at)
);

CREATE UNIQUE INDEX orphan_assignments_one_active
  ON public.orphan_assignments(orphan_id,user_id)
  WHERE is_active;
CREATE INDEX orphan_assignments_user_active
  ON public.orphan_assignments(user_id,orphan_id)
  WHERE is_active;

-- Validate the target profile's current role and active state on assignment writes.
CREATE FUNCTION private.validate_sanad_assignment_target()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
SET row_security TO 'off'
AS $function$
DECLARE
  target_role text;
  target_active boolean;
  assigner_active boolean;
BEGIN
  SELECT p.role, p.is_active
    INTO target_role, target_active
  FROM public.profiles AS p
  WHERE p.id = NEW.user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Assignment target profile does not exist.';
  END IF;

  -- Active assignments require an active target. Ending an old assignment
  -- remains possible after the staff account has been deactivated.
  IF NEW.is_active AND target_active IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'An active assignment requires an active target profile.';
  END IF;

  IF TG_TABLE_NAME = 'case_assignments'
     AND target_role IS DISTINCT FROM NEW.assignment_role THEN
    RAISE EXCEPTION 'Assignment role must match the target profile role.';
  END IF;

  IF TG_TABLE_NAME = 'orphan_assignments'
     AND target_role IS DISTINCT FROM 'orphan_supervisor' THEN
    RAISE EXCEPTION 'Orphan assignment target must have orphan_supervisor role.';
  END IF;

  -- Validate the assigning admin only when the attribution is first set or changed.
  -- Historical assignment rows can still be ended if their original assigner is inactive.
  IF NEW.assigned_by IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.assigned_by IS DISTINCT FROM OLD.assigned_by) THEN
    SELECT p.is_active INTO assigner_active
    FROM public.profiles AS p WHERE p.id = NEW.assigned_by;
    IF assigner_active IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'Assigning administrator must be active.';
    END IF;
  END IF;

  IF NEW.is_active THEN
    NEW.ended_at := NULL;
  ELSIF NEW.ended_at IS NULL THEN
    NEW.ended_at := now();
  END IF;
  RETURN NEW;
END
$function$;

CREATE TRIGGER case_assignments_validate_target
BEFORE INSERT OR UPDATE ON public.case_assignments
FOR EACH ROW EXECUTE FUNCTION private.validate_sanad_assignment_target();

CREATE TRIGGER orphan_assignments_validate_target
BEFORE INSERT OR UPDATE ON public.orphan_assignments
FOR EACH ROW EXECUTE FUNCTION private.validate_sanad_assignment_target();

-- A researcher may create a new case only for themselves. Create the matching
-- assignment in a trusted trigger so the creator can immediately read/update it.
-- This does not permit self-assignment to an existing case.
CREATE FUNCTION private.assign_case_creator_as_researcher()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
SET row_security TO 'off'
AS $function$
DECLARE
  creator_role text;
  creator_active boolean;
BEGIN
  IF NEW.created_by IS DISTINCT FROM (SELECT auth.uid())
     OR NEW.assigned_researcher IS DISTINCT FROM (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'Researchers may create only cases assigned to themselves.';
  END IF;

  SELECT p.role, p.is_active
    INTO creator_role, creator_active
  FROM public.profiles p
  WHERE p.id = (SELECT auth.uid());

  IF creator_role IS DISTINCT FROM 'researcher'
     OR creator_active IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Only an active researcher may self-create an assigned case.';
  END IF;

  INSERT INTO public.case_assignments
    (case_id, user_id, assignment_role, assigned_by, is_active)
  VALUES
    (NEW.id, (SELECT auth.uid()), 'researcher', (SELECT auth.uid()), true);

  RETURN NEW;
END
$function$;

CREATE TRIGGER family_cases_assign_creator
AFTER INSERT ON public.family_cases
FOR EACH ROW
WHEN (NEW.created_by IS NOT NULL AND NEW.assigned_researcher IS NOT NULL)
EXECUTE FUNCTION private.assign_case_creator_as_researcher();

-- Narrow SECURITY DEFINER predicates. They expose only boolean membership.
CREATE OR REPLACE FUNCTION private.has_case_assignment(
  p_case_id uuid,
  p_assignment_role text DEFAULT NULL
)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO ''
SET row_security TO 'off'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.case_assignments ca
    JOIN public.profiles p ON p.id = ca.user_id
    WHERE ca.case_id = p_case_id
      AND ca.user_id = (SELECT auth.uid())
      AND ca.is_active
      AND p.is_active
      AND (p_assignment_role IS NULL OR ca.assignment_role = p_assignment_role)
  );
$function$;

CREATE OR REPLACE FUNCTION private.has_orphan_assignment(p_orphan_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO ''
SET row_security TO 'off'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.orphan_assignments oa
    JOIN public.profiles p ON p.id = oa.user_id
    WHERE oa.orphan_id = p_orphan_id
      AND oa.user_id = (SELECT auth.uid())
      AND oa.is_active
      AND p.is_active
  );
$function$;

REVOKE ALL ON FUNCTION private.validate_sanad_assignment_target() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.assign_case_creator_as_researcher() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.has_case_assignment(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.has_orphan_assignment(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.has_case_assignment(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_orphan_assignment(uuid) TO authenticated;

-- Assignment tables: admin manages; staff sees only their own active assignments.
ALTER TABLE public.case_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orphan_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY case_assignments_admin_all ON public.case_assignments
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY case_assignments_self_read ON public.case_assignments
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) AND is_active);

CREATE POLICY orphan_assignments_admin_all ON public.orphan_assignments
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY orphan_assignments_self_read ON public.orphan_assignments
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) AND is_active);

REVOKE ALL ON public.case_assignments, public.orphan_assignments FROM anon;
REVOKE ALL ON public.case_assignments, public.orphan_assignments FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.case_assignments, public.orphan_assignments TO authenticated;

-- Remove every pre-existing policy on the tables governed below, including policies
-- whose exact names were not preserved in the earlier inventory. This is intentional:
-- leaving one broad permissive policy would OR together with the new restrictions.
-- Review the full resulting policy set before executing this migration.
DO $drop_old_policies$
DECLARE
  target_table text;
  old_policy record;
BEGIN
  FOREACH target_table IN ARRAY ARRAY[
    'family_cases','case_private_details','orphan_profiles',
    'assistance_requests','distribution_records','sponsorships',
    'tasks','complaints','profiles','volunteers','donations',
    'announcements','campaigns','public_aid_intake','audit_logs'
  ] LOOP
    FOR old_policy IN
      SELECT policyname
      FROM pg_policies
      WHERE schemaname = 'public' AND tablename = target_table
    LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', old_policy.policyname, target_table);
    END LOOP;
  END LOOP;
END
$drop_old_policies$;

-- Replace broad role-only policies on operational tables. These DROP statements
-- name only policies confirmed in the supplied policy inventory.
DROP POLICY IF EXISTS family_cases_research_manage ON public.family_cases;
DROP POLICY IF EXISTS family_cases_research_update ON public.family_cases;
DROP POLICY IF EXISTS family_cases_team_read ON public.family_cases;
DROP POLICY IF EXISTS family_cases_admin_delete ON public.family_cases;

CREATE POLICY family_cases_admin_all ON public.family_cases
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY family_cases_researcher_assigned_read ON public.family_cases
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'researcher'
         AND private.has_case_assignment(id,'researcher'));
CREATE POLICY family_cases_researcher_assigned_insert ON public.family_cases
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.current_app_role()) = 'researcher'
              AND created_by = (SELECT auth.uid())
              AND assigned_researcher = (SELECT auth.uid()));
-- The AFTER INSERT trigger above creates the corresponding assignment row.
-- If the trigger is absent or fails, the transaction aborts rather than
-- leaving a case that its creator cannot subsequently access.
CREATE POLICY family_cases_researcher_assigned_update ON public.family_cases
  FOR UPDATE TO authenticated
  USING ((SELECT private.current_app_role()) = 'researcher'
         AND private.has_case_assignment(id,'researcher'))
  WITH CHECK ((SELECT private.current_app_role()) = 'researcher'
              AND private.has_case_assignment(id,'researcher'));
CREATE POLICY family_cases_distributor_assigned_read ON public.family_cases
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'distributor'
         AND private.has_case_assignment(id,'distributor'));

DROP POLICY IF EXISTS private_details_admin_delete ON public.case_private_details;
DROP POLICY IF EXISTS private_details_research_insert ON public.case_private_details;
DROP POLICY IF EXISTS private_details_research_read ON public.case_private_details;
DROP POLICY IF EXISTS private_details_research_update ON public.case_private_details;

CREATE POLICY private_details_admin_all ON public.case_private_details
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY private_details_researcher_assigned_read ON public.case_private_details
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'researcher'
         AND private.has_case_assignment(case_id,'researcher'));
CREATE POLICY private_details_researcher_assigned_insert ON public.case_private_details
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.current_app_role()) = 'researcher'
              AND private.has_case_assignment(case_id,'researcher'));
CREATE POLICY private_details_researcher_assigned_update ON public.case_private_details
  FOR UPDATE TO authenticated
  USING ((SELECT private.current_app_role()) = 'researcher'
         AND private.has_case_assignment(case_id,'researcher'))
  WITH CHECK ((SELECT private.current_app_role()) = 'researcher'
              AND private.has_case_assignment(case_id,'researcher'));

DROP POLICY IF EXISTS orphans_admin_delete ON public.orphan_profiles;
DROP POLICY IF EXISTS orphans_research_read ON public.orphan_profiles;
DROP POLICY IF EXISTS orphans_supervisor_insert ON public.orphan_profiles;
DROP POLICY IF EXISTS orphans_supervisor_update ON public.orphan_profiles;

CREATE POLICY orphan_profiles_admin_all ON public.orphan_profiles
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY orphan_profiles_researcher_assigned_case_read ON public.orphan_profiles
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'researcher'
         AND private.has_case_assignment(case_id,'researcher'));
CREATE POLICY orphan_profiles_supervisor_individual_read ON public.orphan_profiles
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'orphan_supervisor'
         AND private.has_orphan_assignment(id));
CREATE POLICY orphan_profiles_researcher_assigned_insert ON public.orphan_profiles
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.current_app_role()) = 'researcher'
              AND private.has_case_assignment(case_id,'researcher'));
CREATE POLICY orphan_profiles_supervisor_assigned_update ON public.orphan_profiles
  FOR UPDATE TO authenticated
  USING ((SELECT private.current_app_role()) = 'orphan_supervisor'
         AND private.has_orphan_assignment(id))
  WITH CHECK ((SELECT private.current_app_role()) = 'orphan_supervisor'
              AND private.has_orphan_assignment(id));
CREATE POLICY orphan_profiles_researcher_assigned_update ON public.orphan_profiles
  FOR UPDATE TO authenticated
  USING ((SELECT private.current_app_role()) = 'researcher'
         AND private.has_case_assignment(case_id,'researcher'))
  WITH CHECK ((SELECT private.current_app_role()) = 'researcher'
              AND private.has_case_assignment(case_id,'researcher'));

DROP POLICY IF EXISTS requests_admin_delete ON public.assistance_requests;
DROP POLICY IF EXISTS requests_research_insert ON public.assistance_requests;
DROP POLICY IF EXISTS requests_team_read ON public.assistance_requests;
DROP POLICY IF EXISTS requests_team_update ON public.assistance_requests;

CREATE POLICY assistance_requests_admin_all ON public.assistance_requests
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY assistance_requests_researcher_assigned_read ON public.assistance_requests
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'researcher'
         AND private.has_case_assignment(case_id,'researcher'));
CREATE POLICY assistance_requests_researcher_assigned_insert ON public.assistance_requests
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.current_app_role()) = 'researcher'
              AND private.has_case_assignment(case_id,'researcher')
              AND requested_by = (SELECT auth.uid()));
CREATE POLICY assistance_requests_researcher_assigned_update ON public.assistance_requests
  FOR UPDATE TO authenticated
  USING ((SELECT private.current_app_role()) = 'researcher'
         AND private.has_case_assignment(case_id,'researcher'))
  WITH CHECK ((SELECT private.current_app_role()) = 'researcher'
              AND private.has_case_assignment(case_id,'researcher'));
CREATE POLICY assistance_requests_distributor_assigned_read ON public.assistance_requests
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'distributor'
         AND private.has_case_assignment(case_id,'distributor'));
CREATE POLICY assistance_requests_distributor_assigned_update ON public.assistance_requests
  FOR UPDATE TO authenticated
  USING ((SELECT private.current_app_role()) = 'distributor'
         AND private.has_case_assignment(case_id,'distributor'))
  WITH CHECK ((SELECT private.current_app_role()) = 'distributor'
              AND private.has_case_assignment(case_id,'distributor'));

DROP POLICY IF EXISTS distributions_admin_delete ON public.distribution_records;
DROP POLICY IF EXISTS distributions_team_insert ON public.distribution_records;
DROP POLICY IF EXISTS distributions_team_read ON public.distribution_records;
DROP POLICY IF EXISTS distributions_team_update ON public.distribution_records;

CREATE POLICY distribution_records_admin_all ON public.distribution_records
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY distribution_records_distributor_assigned_read ON public.distribution_records
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'distributor'
         AND private.has_case_assignment(case_id,'distributor'));
CREATE POLICY distribution_records_distributor_assigned_insert ON public.distribution_records
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.current_app_role()) = 'distributor'
              AND private.has_case_assignment(case_id,'distributor')
              AND distributor_id = (SELECT auth.uid()));
CREATE POLICY distribution_records_distributor_assigned_update ON public.distribution_records
  FOR UPDATE TO authenticated
  USING ((SELECT private.current_app_role()) = 'distributor'
         AND private.has_case_assignment(case_id,'distributor'))
  WITH CHECK ((SELECT private.current_app_role()) = 'distributor'
              AND private.has_case_assignment(case_id,'distributor')
              AND distributor_id = (SELECT auth.uid()));
CREATE POLICY distribution_records_accountant_read ON public.distribution_records
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'accountant');

DROP POLICY IF EXISTS sponsorships_admin_delete ON public.sponsorships;
DROP POLICY IF EXISTS sponsorships_finance_insert ON public.sponsorships;
DROP POLICY IF EXISTS sponsorships_finance_read ON public.sponsorships;
DROP POLICY IF EXISTS sponsorships_finance_update ON public.sponsorships;

CREATE POLICY sponsorships_admin_all ON public.sponsorships
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY sponsorships_accountant_read ON public.sponsorships
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'accountant');
CREATE POLICY sponsorships_accountant_insert ON public.sponsorships
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.current_app_role()) = 'accountant');
CREATE POLICY sponsorships_accountant_update ON public.sponsorships
  FOR UPDATE TO authenticated
  USING ((SELECT private.current_app_role()) = 'accountant')
  WITH CHECK ((SELECT private.current_app_role()) = 'accountant');

DROP POLICY IF EXISTS tasks_admin_delete ON public.tasks;
DROP POLICY IF EXISTS tasks_admin_research_insert ON public.tasks;
DROP POLICY IF EXISTS tasks_assignee_update ON public.tasks;
DROP POLICY IF EXISTS tasks_read_assigned_or_admin ON public.tasks;

CREATE POLICY tasks_admin_all ON public.tasks
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY tasks_assignee_read ON public.tasks
  FOR SELECT TO authenticated
  USING (assigned_to = (SELECT auth.uid()));
CREATE POLICY tasks_researcher_case_read ON public.tasks
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'researcher'
         AND related_case_id IS NOT NULL
         AND private.has_case_assignment(related_case_id,'researcher'));
CREATE POLICY tasks_assignee_update ON public.tasks
  FOR UPDATE TO authenticated
  USING (assigned_to = (SELECT auth.uid()))
  WITH CHECK (assigned_to = (SELECT auth.uid()));
CREATE POLICY tasks_admin_researcher_insert ON public.tasks
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.current_app_role()) IN ('admin','researcher')
              AND created_by = (SELECT auth.uid()));

DROP POLICY IF EXISTS complaints_admin_update ON public.complaints;
DROP POLICY IF EXISTS complaints_assigned_admin_read ON public.complaints;
DROP POLICY IF EXISTS complaints_authenticated_insert ON public.complaints;

CREATE POLICY complaints_admin_all ON public.complaints
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY complaints_assignee_read ON public.complaints
  FOR SELECT TO authenticated
  USING (assigned_to = (SELECT auth.uid()));
CREATE POLICY complaints_authenticated_insert ON public.complaints
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Profiles remain self-read/admin-read. Admin is the only role that can mutate.
DROP POLICY IF EXISTS profiles_admin_delete ON public.profiles;
DROP POLICY IF EXISTS profiles_admin_insert ON public.profiles;
DROP POLICY IF EXISTS profiles_admin_update ON public.profiles;
DROP POLICY IF EXISTS profiles_read_self_or_admin ON public.profiles;

CREATE POLICY profiles_admin_all ON public.profiles
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY profiles_self_read ON public.profiles
  FOR SELECT TO authenticated
  USING (id = (SELECT auth.uid()));

-- Volunteer self-read; volunteer profile mutation remains admin-only.
DROP POLICY IF EXISTS volunteers_admin_delete ON public.volunteers;
DROP POLICY IF EXISTS volunteers_admin_insert ON public.volunteers;
DROP POLICY IF EXISTS volunteers_admin_or_self_read ON public.volunteers;
DROP POLICY IF EXISTS volunteers_admin_update ON public.volunteers;

CREATE POLICY volunteers_admin_all ON public.volunteers
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY volunteers_self_read ON public.volunteers
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- Donations: accountant/admin only.
DROP POLICY IF EXISTS donations_admin_delete ON public.donations;
DROP POLICY IF EXISTS donations_finance_read ON public.donations;
DROP POLICY IF EXISTS donations_finance_update ON public.donations;

CREATE POLICY donations_admin_all ON public.donations
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY donations_accountant_read ON public.donations
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'accountant');
CREATE POLICY donations_accountant_update ON public.donations
  FOR UPDATE TO authenticated
  USING ((SELECT private.current_app_role()) = 'accountant')
  WITH CHECK ((SELECT private.current_app_role()) = 'accountant');

-- Public announcements/campaigns remain public only when published.
-- Existing known policies are replaced to prevent accidental permissive OR paths.
DROP POLICY IF EXISTS announcements_admin_delete ON public.announcements;
DROP POLICY IF EXISTS announcements_admin_insert ON public.announcements;
DROP POLICY IF EXISTS announcements_admin_update ON public.announcements;
DROP POLICY IF EXISTS announcements_public_read ON public.announcements;

CREATE POLICY announcements_admin_all ON public.announcements
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY announcements_published_read ON public.announcements
  FOR SELECT TO anon, authenticated
  USING (is_published = true);

DROP POLICY IF EXISTS campaigns_admin_delete ON public.campaigns;
DROP POLICY IF EXISTS campaigns_public_read ON public.campaigns;
DROP POLICY IF EXISTS campaigns_finance_insert ON public.campaigns;
DROP POLICY IF EXISTS campaigns_finance_update ON public.campaigns;

CREATE POLICY campaigns_admin_all ON public.campaigns
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');
CREATE POLICY campaigns_accountant_read ON public.campaigns
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'accountant');
CREATE POLICY campaigns_published_read ON public.campaigns
  FOR SELECT TO anon, authenticated
  USING (status = 'published');
CREATE POLICY campaigns_accountant_insert ON public.campaigns
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.current_app_role()) = 'accountant');
CREATE POLICY campaigns_accountant_update ON public.campaigns
  FOR UPDATE TO authenticated
  USING ((SELECT private.current_app_role()) = 'accountant')
  WITH CHECK ((SELECT private.current_app_role()) = 'accountant');

-- Public intake: anonymous insert only; admins manage submitted records.
DROP POLICY IF EXISTS public_aid_intake_anon_insert ON public.public_aid_intake;
DROP POLICY IF EXISTS public_aid_intake_admin_read ON public.public_aid_intake;
DROP POLICY IF EXISTS public_aid_intake_admin_update ON public.public_aid_intake;
DROP POLICY IF EXISTS public_aid_intake_admin_delete ON public.public_aid_intake;

CREATE POLICY public_aid_intake_anon_insert ON public.public_aid_intake
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);
CREATE POLICY public_aid_intake_admin_all ON public.public_aid_intake
  FOR ALL TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin')
  WITH CHECK ((SELECT private.current_app_role()) = 'admin');

-- Audit logs: read-only to admins via RLS; no client write policy is added.
-- Keep existing admin SELECT policy if present; replace only the known policy name.
DROP POLICY IF EXISTS audit_logs_admin_read ON public.audit_logs;
CREATE POLICY audit_logs_admin_read ON public.audit_logs
  FOR SELECT TO authenticated
  USING ((SELECT private.current_app_role()) = 'admin');

-- NOTE: this draft deliberately does not alter table grants, default privileges,
-- Auth settings, or service_role access. It also does not solve role-specific
-- financial column visibility; a separately reviewed view/API migration is required.

COMMIT;

-- REQUIRED POST-MIGRATION VALIDATION (run only after approved staging deployment):
-- 1) Verify RLS enabled on every public table above.
-- 2) Inspect pg_policies: no old broad permissive policy remains on protected tables.
-- 3) Test all six roles with separate real sessions, plus anon.
-- 4) Verify role changes/self-escalation are denied.
-- 5) Verify ended assignments and inactive profiles immediately lose access.
-- 6) Verify orphan supervisor cannot see unassigned sibling orphans.
-- 7) Verify financial data through a separate column-safe interface; this file
--    alone does NOT guarantee column-level confidentiality.
-- 8) Test all actual app queries and inserts before production release.
