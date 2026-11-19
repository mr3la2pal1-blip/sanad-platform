-- SANAD POST-DEPLOYMENT READ-ONLY VERIFICATION
-- Safe inspection only: SELECT statements; no schema or data changes.
-- Run only after an approved staging migration. Do not treat this as a role simulation.

SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS force_rls
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = ANY (ARRAY[
    'profiles','family_cases','case_private_details','orphan_profiles',
    'sponsorships','assistance_requests','distribution_records','tasks',
    'audit_logs','complaints','volunteers','donations','announcements',
    'campaigns','public_aid_intake','case_assignments','orphan_assignments'
  ])
  AND c.relkind = 'r'
ORDER BY c.relname;

SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = ANY (ARRAY[
    'profiles','family_cases','case_private_details','orphan_profiles',
    'sponsorships','assistance_requests','distribution_records','tasks',
    'audit_logs','complaints','volunteers','donations','announcements',
    'campaigns','public_aid_intake','case_assignments','orphan_assignments'
  ])
ORDER BY tablename, policyname;

SELECT
  to_regclass('public.case_assignments') AS case_assignments_table,
  to_regclass('public.orphan_assignments') AS orphan_assignments_table,
  to_regprocedure('private.has_case_assignment(uuid,text)') AS case_assignment_helper,
  to_regprocedure('private.has_orphan_assignment(uuid)') AS orphan_assignment_helper,
  to_regprocedure('private.assign_case_creator_as_researcher()') AS researcher_case_creator_trigger_function;

SELECT
  tg.tgname AS trigger_name,
  c.relname AS table_name,
  pg_get_triggerdef(tg.oid, true) AS trigger_definition
FROM pg_trigger tg
JOIN pg_class c ON c.oid = tg.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT tg.tgisinternal
  AND n.nspname = 'public'
  AND c.relname IN ('family_cases','case_assignments','orphan_assignments')
ORDER BY c.relname, tg.tgname;

-- Session-context check: run separately while signed in as each real test user.
SELECT
  auth.uid() AS authenticated_user_id,
  auth.role() AS jwt_role,
  private.current_app_role() AS application_role;
