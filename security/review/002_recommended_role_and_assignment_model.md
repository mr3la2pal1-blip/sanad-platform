# SANAD — Recommended authorization model

Status: design specification for review. This document changes no production code or database.

## 1. Recommended assignment granularity

Use two distinct assignment scopes rather than forcing every role into one case-level link:

- `case_assignments`: one active assignment per case, user and role for `researcher` or `distributor`.
- `orphan_assignments`: one active assignment per orphan and user for `orphan_supervisor`.

Reason: an orphan supervisor should see only the individual orphan records assigned to them, even when siblings belong to the same family. The reviewed `case_assignments` draft requires `case_id` and cannot express this safely by itself. Do not treat a case assignment as automatic permission to see every orphan in that case.

Each assignment must target an existing active profile whose `profiles.role` exactly matches the assignment role. Only an administrator may create, end, or reassign assignments. Staff may read only their own active assignment rows. Preserve assignment history; end assignments rather than deleting them during normal operations.

## 2. Role access policy

| Role | Allowed scope | Explicitly excluded |
|---|---|---|
| Admin | All operational records and user/assignment administration | None within the application; sensitive actions should be audited |
| Researcher | Assigned family cases; minimum private details needed for field work; related requests/orphans only when operationally necessary | Donations, sponsor payment details, unrelated cases |
| Orphan supervisor | Individually assigned orphan profiles and minimum linked case context | Sponsorship amounts, donor identity/contact, unrelated siblings unless separately assigned |
| Distributor | Assigned cases, their assistance requests, and distribution records needed to fulfil them | Private case notes, sponsorship and donation data, unassigned cases |
| Accountant | Donations, sponsorships, financial status/references, and distribution totals/records needed for reconciliation | Private social notes, detailed case narratives, orphan private notes |
| Volunteer | Own profile and explicitly assigned volunteer tasks | Beneficiary records and all financial records unless a separate approved workflow requires a narrowly scoped view |

## 3. Financial and private-field separation

RLS controls rows, not individual columns. Do not claim that an orphan supervisor is financially restricted merely because their row policy is restricted.

Use column-level grants or a narrowly scoped view/RPC for role-specific field exposure, after reviewing existing table grants and every application query. Avoid broad table-level grants that unintentionally expose financial columns. Do not revoke column privileges based only on `information_schema.column_privileges`: table-level grants can appear in that view too.

Minimum recommended field boundaries:

- Orphan supervisor: orphan identity/internal code, age/status, and case context strictly needed for child safeguarding. No `sponsorships.amount`, `currency`, `sponsor_reference`, or financial notes.
- Researcher: contact/address/private details only where required for assessment and follow-up; no donor or sponsor financial fields.
- Distributor: request category, priority, delivery status, quantity and recipient confirmation; no private case notes or sponsor data.
- Accountant: transaction amounts, currency, payment status, campaign/sponsorship references and distribution reconciliation fields. Donor identity/contact only if the accounting process demonstrably requires it.

## 4. RLS migration rules

1. Inventory existing policies and grants immediately before migration.
2. Replace conflicting permissive policies; do not simply add narrower permissive policies beside broad ones. PostgreSQL permissive policies combine with OR.
3. Apply assignment predicates on the database side, never rely on browser filtering.
4. For linked tables, derive access through the parent case/request/orphan foreign key.
5. Keep public anonymous intake limited to INSERT with validated input. Anonymous users must not read intake records.
6. Keep profile role changes administrator-only. A user must never be able to update their own role or active flag.
7. Do not change default privileges or broad grants without an identified owner-authorized migration and a complete server-side usage inventory.
8. Do not enable FORCE RLS as a blanket measure.

## 5. Important schema-specific caution

The reviewed schema includes `complaints.assigned_to` but did not show a reliable submitter/owner column. Therefore, do not invent a self-service complaint policy or assume that `assigned_to` represents the submitter. Decide whether complaints are administrator-only for reading, or add a properly designed `created_by`/submitter field in a separate reviewed schema change.

The existing `tasks` policy allows researchers to read all tasks, not just their own. Tighten this only after confirming whether researchers need task visibility for coordination; default recommendation is own assigned tasks plus tasks explicitly linked to cases assigned to them.

## 6. Acceptance tests required before release

Run with separate real authenticated accounts for all six roles, plus anonymous access. Use at least two cases and two orphans, with assignments split across two staff accounts.

- Assigned researcher can read assigned case and required private details; cannot read an unassigned case.
- Researcher cannot read donation/sponsorship financial records.
- Orphan supervisor can read assigned orphan; cannot read an unassigned orphan, even if linked to the same family; cannot read sponsorship amounts or donor contact.
- Distributor can read/update only assigned requests and record valid deliveries; cannot access unrelated case/private details.
- Accountant can read required financial records but cannot read private case notes or orphan private notes.
- Volunteer can read their own profile and permitted tasks only.
- Every non-admin role is denied attempts to change profiles.role, profiles.is_active, assignments, or another user's profile.
- Anonymous user can submit valid public intake but cannot select, update, or delete intake rows.
- Ended assignments immediately stop granting access.
- Inactive users receive no assignment-derived access.
- Admin can administer all intended records; sensitive operations are auditable.

Test both allowed and denied INSERT/UPDATE/DELETE paths, not only SELECT. Verify that the app's actual queries still work under the final grants.

## 7. Deployment sequence

1. Review and approve the schema/role design.
2. Prepare a complete migration that creates both assignment tables, validates target roles, and replaces affected policies atomically.
3. Run preflight and backup/rollback preparation.
4. Apply in staging first; seed test users and representative data.
5. Run the acceptance tests above.
6. Update role interfaces to match the enforced database boundaries.
7. Deploy to production only after successful staging verification.

No SQL has been executed and no production behavior has been changed by this specification.
