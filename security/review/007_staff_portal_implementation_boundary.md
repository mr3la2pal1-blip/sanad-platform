# Sanad staff portal — implementation boundary

Status: UI specification only. The current repository has a public landing page and an admin dashboard; it does not yet contain six tested staff portals.

## Why the staff UI is not wired to Supabase yet
The RLS migration has not been applied to a staging database, and the app currently uses direct table queries. Wiring researcher, orphan supervisor, distributor, accountant, and volunteer screens before the database boundary is enforced could expose beneficiary or financial data. A frontend-only filter is not a security control.

## Shared staff shell
- Authenticated session check; redirect signed-out users to sign-in.
- Read the current user's own profile and display only the role returned by the database.
- Never accept a role from URL parameters, local storage, or editable client state.
- Show only the navigation relevant to the verified role, while relying on RLS for every data request.
- Provide sign-out, session-expiry handling, loading/error states, and accessible mobile layout.
- Do not put service-role credentials in browser code.

## Role screens and minimum data
### Researcher
Assigned family case list; case status/priority; minimum contact/private details; associated requests; create case only through the approved self-assignment trigger workflow.

### Orphan supervisor
Individually assigned orphan list; child safeguarding status and only the minimum linked case context. No direct sponsorship or donation queries.

### Distributor
Assigned assistance requests; delivery schedule/status; quantity and recipient confirmation. No private case notes.

### Accountant
Donations, sponsorships, campaign finance and distribution reconciliation. No orphan private notes or case narratives.

### Volunteer
Own volunteer profile and tasks explicitly assigned to the authenticated user. No beneficiary record access.

### Admin
Existing administration dashboard, with a server-enforced admin check and audited assignment/profile actions.

## Integration sequence
1. Apply corrected SQL only in staging.
2. Pass the acceptance test plan for all roles.
3. Refactor direct queries into role-specific data modules.
4. Add staff screens using only columns granted to that role.
5. Run browser regression tests and negative authorization tests.
6. Deploy only after staging evidence is attached to the PR.

## Explicit non-goals
- No demo data presented as real beneficiary records.
- No frontend-only authorization.
- No hardcoded credentials or service-role key.
- No production UI switch before RLS is active and verified.
