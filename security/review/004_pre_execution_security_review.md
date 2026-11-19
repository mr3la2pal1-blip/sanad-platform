# Sanad — Pre-execution security review (2026-11-20)

Status: BLOCKED — review only; do not execute migration 003 in production.

Reviewed artifact:
- security/review/003_role_rls_migration_draft.sql
- Previously supplied Supabase inventory and schema results (15 public tables; RLS enabled; existing role policies; known columns and foreign keys).

## Findings requiring correction before execution

### 1. Researcher-created case becomes inaccessible
The draft's `family_cases_researcher_assigned_insert` requires `assigned_researcher = auth.uid()`, but subsequent researcher read/update policies require a matching active row in `case_assignments`. The insert policy does not create that assignment row. A researcher-created case can therefore be inserted but then remain invisible to that researcher.

Required decision: either make case creation admin-only and have an admin assign it, or implement a reviewed, secure assignment-creation flow that cannot let a researcher self-assign arbitrary existing cases. Do not solve this by weakening the read policy.

### 2. Financial-column confidentiality is not implemented
RLS filters rows, not individual columns. The draft correctly acknowledges this, but the intended rule (orphan supervisor must not see sponsorship amounts/financial notes) is not enforced by migration 003. Existing table-level grants may still permit selecting those columns for rows allowed by RLS.

Required work: design a separate, explicitly granted column-safe interface (for example, a restricted view with carefully verified underlying privileges, or a server-side API/RPC with a narrow return shape), then remove direct base-table column access only after app queries are migrated and verified. Do not issue broad column REVOKEs based solely on information_schema.column_privileges; those results may reflect table-level grants.

### 3. Policy replacement is intentionally destructive to policy configuration
The dynamic block drops every policy on 15 tables, including any policy added after the supplied inventory. The replacement set must be reconciled against a fresh policy export immediately before execution. The current inventory is historical evidence, not a live schema connection.

Required work: generate a deterministic before/after policy manifest and abort if unexpected policies are present. Review all command paths in the app against the replacement policies.

### 4. Existing application compatibility is not yet proven
The website/admin code reads several tables directly. The proposed restrictions will change which rows are returned and which writes succeed. No role-by-role browser/API regression test has been run against a staging Supabase project.

Required work: stage the migration and test actual app queries with separate sessions for admin, researcher, orphan supervisor, distributor, accountant, volunteer, and anon.

### 5. Assignment lifecycle and authorization need staging tests
The assignment triggers validate the target role and active status. Before production, test:
- only an active admin can create/change assignments through authenticated access;
- target profile role matches assignment type;
- inactive targets and ended assignments lose access immediately;
- reassignment history is retained;
- case deletion and orphan deletion have the intended cascade behavior;
- no user can modify another user's assignment rows.

### 6. Public intake and complaint submission need abuse controls
The draft retains anonymous public intake INSERT and authenticated complaint INSERT. RLS alone does not provide rate limiting, spam controls, validation, or abuse monitoring. Complaint INSERT currently permits any authenticated user and has no confirmed submitter column for self-read.

Required work: validate payload constraints and add server-side rate limiting / abuse controls before treating these endpoints as production-hardened.

### 7. Grants and default privileges are deliberately untouched
This is appropriate given the prior permission-denied result for default privileges and the risk of confusing table grants with column-level grants. Do not retry broad default-privilege changes from an unprivileged SQL Editor role. Any grant change must be a separate, narrowly scoped, reviewed migration.

## Safe next sequence

1. Correct the researcher case-creation workflow and policy.
2. Design and test the finance-safe interface for orphan supervisors.
3. Produce a fresh read-only schema/policy/grant snapshot immediately before deployment.
4. Reconcile the complete policy manifest; fail closed on drift.
5. Apply the corrected migration only in a staging project first.
6. Run role-based positive and negative tests, plus app regression tests.
7. Only after passing tests, present the final production SQL for explicit approval.

## Execution record

- No SQL was executed against Supabase.
- No existing Supabase policy, grant, table, or function was changed by this review.
- No Render deployment was performed.
- This document and migration 003 are review artifacts only.
