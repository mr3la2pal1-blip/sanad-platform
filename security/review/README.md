# SANAD — Security hardening implementation package

**Branch:** `security-review/staged-hardening`  
**Base:** `main`  
**Status:** review branch only. No production deployment, database change, or merge performed.

## What was verified from the current repository
The current `admin.html` is an administrator-only interface: it reads the current user's profile and checks `role === 'admin'` and `is_active`. The dashboard queries tables directly and does not add assignment filters in the browser. This is not proof of a data leak by itself; RLS must enforce the row boundary.

The dashboard currently reads campaign, family case, assistance request, orphan, volunteer, announcement, donation, and public-intake data. The `is_sanad_admin` RPC result is displayed diagnostically but is not itself used as the gate that hides the dashboard. The UI must not be treated as the security boundary.

The public intake form inserts into `public_aid_intake` using the Supabase publishable browser key. This is expected for a browser client only when anonymous grants and RLS are tightly limited to insert.

The password-reset counter is stored in browser localStorage and is therefore not server-side rate limiting. Configure actual Auth/email provider limits; do not rely on the client counter.

## Target access matrix
- Admin: all operational records and administration.
- Researcher: assigned cases, associated private details only to the extent required, and associated orphan records.
- Orphan supervisor: assigned orphan files and linked case information; no sponsorship amounts or other financial details.
- Distributor: assistance requests and distributions for assigned cases only.
- Accountant: financial, sponsorship and distribution information required for accounting; minimize unrelated personal data.
- Volunteer: own profile only.

## Six completion workstreams
1. **Assignment foundation:** create and validate case assignment records, with assignment-role validation and active-assignment lifecycle.
2. **RLS replacement:** replace—not merely supplement—existing permissive policies for case, private detail, orphan, request, distribution, sponsorship, task and complaint tables. PostgreSQL permissive policies combine with OR, so additive policies can widen access.
3. **Sensitive data separation:** keep sponsorship and donation amounts, donor contact and sponsor references away from orphan supervisors unless explicitly required. RLS is row-level; it does not by itself hide selected columns.
4. **Role interfaces:** build separate least-privilege screens only after the matching RLS policies are deployed and tested. The current admin UI is not a six-role portal.
5. **Acceptance tests:** use real sessions for all six roles and anon; prove denied reads/writes for unassigned records, self-role escalation, and private/financial data.
6. **Staged release:** deploy to a preview/staging environment, verify public intake, auth, recovery, dashboards and workflows, then release production.

## Known blockers to a safe final migration
- The reviewed complaint schema did not expose a reliable submitter/owner column. Do not invent one in a policy.
- Confirm whether orphan-supervisor assignments are case-level or orphan-level.
- Confirm the minimum private fields a researcher needs.
- Confirm whether accountants require donor identity/contact fields or only financial references.
- Inventory all server-side/Edge Function use before changing grants or defaults.
- Validate assignment target profile role and active status in a trusted database-side path.

## Repository changes in this branch
- `security/review/README.md`: this review and staged work plan.
- `security/review/001_case_assignments_foundation.sql`: guarded draft for the case-level assignment foundation only. It is explicitly not a production-ready migration.
- `security/review/002_recommended_role_and_assignment_model.md`: recommended least-privilege role matrix, separate orphan-level assignment design, field boundaries, RLS migration rules, acceptance tests, and staged deployment sequence.
- `security/review/003_role_rls_migration_draft.sql`: proposed full role/assignment RLS migration draft. It replaces existing policies on the listed tables and must be reviewed and tested in staging. It does not provide role-specific financial column isolation; that requires a separate view/API and grants design.
- `security/review/004_pre_execution_security_review.md`: initial pre-execution findings; migration 003 remains blocked and is retained as historical draft.
- `security/review/005_corrected_role_rls_migration_draft.sql`: revised review draft. Adds a trusted trigger to create a matching assignment when a researcher creates a case for themselves, permits ending assignments after a target is deactivated, and aborts on unexpected policy-name drift. Still requires a fresh Supabase inventory, staging execution, and full review; not production-ready.
- `security/review/006_security_acceptance_test_plan.md`: positive/negative test cases for all roles and lifecycle events.
- `security/review/007_staff_portal_implementation_boundary.md`: role-screen requirements and safe order for frontend integration. No staff portal is wired yet.
- `security/review/008_post_deployment_readonly_verification.sql`: read-only SQL checks for RLS, policies, triggers, assignment helpers, and current session role.\n- `security/review/009_financial_column_isolation_draft.sql`: separate staging-only draft for admin-only orphan view, assigned-orphan supervisor view, and accountant/admin sponsorship view. It revokes direct client SELECT from the two base tables, so it must be tested together with the updated admin dashboard query and all actual app paths.\n- `admin.html`: the admin orphan list now reads from `admin_orphan_profiles_view`; its INSERT form still writes to `orphan_profiles` and must be regression-tested after the grants change.

## Current release status\n- Migration 005 and migration 009 are review drafts only. They have not been executed against Supabase.\n- Migration 009 is designed to address the previously identified sponsorship-column exposure, but the boundary is not proven until effective table/column/PUBLIC privileges and view ownership are verified in staging.\n- The admin orphan-list query was changed in this branch to use the restricted admin view. No other staff portal has been implemented.\n\n## Explicitly not done
- No SQL executed against Supabase.
- No existing RLS policies changed.
- No production tables or records modified.
- No application UI changed or released.
- No PR merged and no production deployment triggered.

This is intentional: changing production RLS based on unresolved ownership and column-scope questions could lock out legitimate staff or expose beneficiary data.
