-- SANAD FINANCIAL / ORPHAN COLUMN-ISOLATION — REVIEW DRAFT ONLY
-- DO NOT RUN IN PRODUCTION.
-- Apply only AFTER 005 has been reviewed and in an isolated staging project.
-- This migration changes SELECT access on two base tables. It is intentionally
-- separate so the view contract and UI query change can be tested together.
--
-- Design:
--   * admin reads orphan data through an admin-only view;
--   * orphan supervisors read only individually assigned, non-financial orphan fields;
--   * accountants/admins read sponsorship finance through a finance-only view;
--   * authenticated clients lose direct SELECT on the two base tables.
--
-- Existing INSERT/UPDATE/DELETE grants are not modified. No donations grants
-- are changed here. No service_role/default privileges are changed.

BEGIN;

DO $preflight$
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Run this reviewed migration only as postgres in staging; current_user=%', current_user;
  END IF;

  IF to_regclass('public.orphan_profiles') IS NULL
     OR to_regclass('public.sponsorships') IS NULL
     OR to_regprocedure('private.current_app_role()') IS NULL
     OR to_regprocedure('private.has_orphan_assignment(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Required tables or security helper functions are missing; aborting.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='orphan_profiles'
      AND column_name='private_notes'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='sponsorships'
      AND column_name='sponsor_reference'
  ) THEN
    RAISE EXCEPTION 'Reviewed column inventory has drifted; refresh schema snapshot.';
  END IF;
END
$preflight$;

-- Views run with their owner privileges. Explicit role/assignment predicates
-- are therefore mandatory; do not remove or weaken them.
CREATE OR REPLACE VIEW public.admin_orphan_profiles_view
WITH (security_barrier = true)
AS
SELECT id, case_id, internal_code, age_years, status, private_notes, created_at, updated_at
FROM public.orphan_profiles
WHERE (SELECT private.current_app_role()) = 'admin';

CREATE OR REPLACE VIEW public.orphan_supervisor_orphans_view
WITH (security_barrier = true)
AS
SELECT id, case_id, internal_code, age_years, status, created_at, updated_at
FROM public.orphan_profiles
WHERE (SELECT private.current_app_role()) = 'orphan_supervisor'
  AND private.has_orphan_assignment(id);

CREATE OR REPLACE VIEW public.sponsorships_finance_view
WITH (security_barrier = true)
AS
SELECT id, orphan_id, amount, currency, frequency, starts_on, ends_on,
       status, sponsor_reference, notes, created_at
FROM public.sponsorships
WHERE (SELECT private.current_app_role()) IN ('admin','accountant');

ALTER VIEW public.admin_orphan_profiles_view OWNER TO postgres;
ALTER VIEW public.orphan_supervisor_orphans_view OWNER TO postgres;
ALTER VIEW public.sponsorships_finance_view OWNER TO postgres;

-- Remove both table-level and any known column-level SELECT paths from client
-- roles. Revoke from PUBLIC as well, so inherited PUBLIC access cannot bypass
-- the view boundary. Other CRUD privileges are deliberately untouched.
REVOKE SELECT ON TABLE public.orphan_profiles, public.sponsorships
  FROM PUBLIC, anon, authenticated;

REVOKE SELECT (
  id, case_id, internal_code, age_years, status, private_notes, created_at, updated_at
) ON TABLE public.orphan_profiles FROM PUBLIC, anon, authenticated;

REVOKE SELECT (
  id, orphan_id, amount, currency, frequency, starts_on, ends_on,
  status, sponsor_reference, notes, created_at
) ON TABLE public.sponsorships FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.admin_orphan_profiles_view,
                public.orphan_supervisor_orphans_view,
                public.sponsorships_finance_view
TO authenticated;

COMMIT;

-- STAGING ACCEPTANCE CHECKS (must be run with separate real Auth sessions):
-- 1. Admin can SELECT admin_orphan_profiles_view and sponsorships_finance_view.
-- 2. Orphan supervisor can SELECT only assigned rows from orphan_supervisor_orphans_view.
-- 3. Orphan supervisor cannot query amount/currency/frequency/sponsor_reference/notes
--    through any view or either base table.
-- 4. Accountant can SELECT sponsorships_finance_view but cannot read orphan private_notes.
-- 5. Researcher/distributor/volunteer cannot SELECT either base table or these views
--    unless a separately approved role contract explicitly grants a view.
-- 6. Anonymous cannot SELECT either base table or any of these views.
-- 7. Admin dashboard orphan list still loads through admin_orphan_profiles_view.
-- 8. Admin orphan creation INSERT still works through the existing base-table INSERT
--    privilege; test it in the actual UI.
-- 9. Inspect pg_class.relowner and pg_views; confirm all three views are owned by
--    postgres and their WHERE predicates match this reviewed definition.
-- 10. Inspect effective privileges, including PUBLIC and column-level ACLs.
--
-- IMPORTANT:
-- The current staff portal is not implemented. This creates safe data interfaces,
-- not a completed orphan-supervisor/accountant UI. Do not claim those portals are live.
