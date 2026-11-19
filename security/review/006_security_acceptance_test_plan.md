# Sanad security acceptance test plan

Status: test specification only. No tests against live Supabase have been run.

## Test fixture (staging only)
Create separate authenticated test accounts for:
- admin A
- researcher R1 and researcher R2
- orphan supervisor O1 and O2
- distributor D1 and D2
- accountant C1
- volunteer V1
Also use an anonymous browser session.

Create two unrelated family cases (A and B), with at least two orphan profiles under case A and one under case B. Assign:
- R1 and D1 to case A
- R2 and D2 to case B
- O1 to orphan A1 only
- O2 to orphan A2 only
Keep at least one unassigned case and orphan.

Never use real beneficiary records for the test fixture.

## Positive and negative tests

| Actor | Allowed | Must be denied |
|---|---|---|
| Admin | Read/write all operational records; manage assignments and profiles | None within approved admin workflow; sensitive actions should be logged |
| R1 | Read/update case A, its required private details and linked assistance requests; create a new case assigned to self | Read case B; read donation/sponsorship finance; alter role or assignment rows |
| R2 | Same as R1 for case B | Read case A |
| O1 | Read/update orphan A1 only | Read sibling A2, orphan B1, sponsorships or donations |
| O2 | Read/update orphan A2 only | Read sibling A1 |
| D1 | Read assigned case A requests; create/update deliveries for case A | Read case B, private notes, orphan private notes, sponsorships/donations |
| D2 | Same for case B | Read case A |
| C1 | Read/update accounting records; read distributions for reconciliation | Read private case details and orphan private notes |
| V1 | Read own volunteer record and own assigned tasks | Read another volunteer, beneficiary records, financial records |
| anon | Insert valid public intake | Select/update/delete intake rows and access any protected table |

## Lifecycle tests
1. End an assignment: access through that assignment must stop immediately.
2. Deactivate a target profile: all assignment-derived access must stop; admin must still be able to end the historical assignment.
3. Reassign a case/orphan: previous assignee loses access; new assignee gains only the new scope.
4. Attempt role mismatch (e.g. assign accountant as researcher): database must reject.
5. Attempt self-assignment to an existing case by a researcher: database must reject.
6. Create a case as an active researcher with created_by and assigned_researcher equal to auth.uid(): the trigger must create the matching researcher assignment.
7. Attempt to update profiles.role or profiles.is_active as a non-admin: denied.
8. Attempt direct INSERT/UPDATE/DELETE on assignment tables as non-admin: denied.
9. Attempt to access an unassigned record by guessing its UUID: denied.
10. Verify public intake accepts expected fields but never returns submitted records to anon.

## Test method
- Use actual independent Supabase Auth sessions. Do not emulate roles by changing a JWT claim or running as postgres.
- Run both the actual browser app queries and direct PostgREST requests for allowed and denied cases.
- Capture SQLSTATE/HTTP status and returned row counts.
- A zero-row SELECT is a valid denial result; verify writes fail or affect zero rows.
- Confirm no broad permissive policy remains after migration.
- Test with a fresh policy/grant inventory immediately before and after staging deployment.

## Release gate
Do not deploy to production until every negative test is denied, every required positive test succeeds, and all current app screens work with the final grants. Record evidence and rollback steps in the PR.

## Financial-column isolation tests (migration 009)

Use the dedicated views, not simulated role claims:

- Admin A: `admin_orphan_profiles_view` and `sponsorships_finance_view` return the expected admin rows.
- Orphan supervisor O1: `orphan_supervisor_orphans_view` returns only the individually assigned orphan; the view has no financial columns.
- O1: direct SELECT from `orphan_profiles` and `sponsorships` is denied, including attempts to name `amount`, `currency`, `frequency`, `sponsor_reference`, or `notes`.
- Accountant C1: `sponsorships_finance_view` works; direct base-table SELECT is denied; private orphan notes are not exposed through the orphan views.
- Researcher, distributor, volunteer, and anon: no access to either base table or the new views unless a separately reviewed role-specific view is later approved.
- Admin dashboard: orphan list loads from `admin_orphan_profiles_view`; orphan creation still succeeds through the existing INSERT path.
- Inspect effective ACLs (table, column, PUBLIC, and inherited grants), view ownership, and exact view definitions after migration.

Migration 009 is a separate staging-only draft. It must not be run before migration 005 and must not be considered production-ready until all tests above pass.
