# Sanad security package — static review results

Date: 2026-11-20
Scope: GitHub branch `security-review/staged-hardening`; files 005, 009, 006, admin.html, app.js.
Method: source inspection and deterministic text/contract checks only. No database connection or SQL execution was available.

## Checks completed

| Check | Result | Evidence |
|---|---|---|
| Migration 005 has explicit transaction boundaries | PASS (static) | BEGIN / COMMIT present |
| Assignment target role and active-profile checks | PASS (static) | Trigger checks role and active state |
| Admin and researcher case-creation branches | PASS (static) | Both branches present |
| Policy drift guard | PASS (static) | Unexpected policy names abort migration |
| Migration 009 has explicit transaction boundaries | PASS (static) | BEGIN / COMMIT present |
| Supervisor view omits amount/currency/frequency/sponsor reference/notes | PASS (static) | Projection contains only orphan identity, case link, age/status and timestamps |
| Supervisor view requires individual orphan assignment | PASS (static) | `private.has_orphan_assignment(id)` predicate |
| Sponsorship finance view limited to admin/accountant role | PASS (static) | Role predicate in view |
| Direct SELECT revoked on orphan_profiles and sponsorships | PASS (static) | Table and known column SELECT revocations present |
| Admin orphan list uses restricted admin view | PASS (static) | `admin.html` query switched to `admin_orphan_profiles_view` |
| View contains dashboard sort column | PASS (static) | `created_at` is projected |

These are source-level checks only. They do not prove PostgreSQL syntax, runtime permissions, RLS behavior, view-owner behavior, or data isolation.

## Remaining blockers — not passed

1. **No live PostgreSQL/Supabase execution:** neither migration 005 nor 009 has been run in staging. Syntax, object ownership, ACL effects, trigger behavior, and rollback have not been demonstrated.
2. **Effective privilege verification:** must inspect table-level, column-level, PUBLIC, inherited, and role-membership privileges after migration 009. The view-owner security boundary must be tested using actual authenticated sessions.
3. **Role-session tests:** admin, researcher, orphan supervisor, distributor, accountant, volunteer, and anon still require separate real sessions with positive and negative assertions.
4. **Application regression:** the admin orphan list and orphan INSERT form need browser/API tests against staging. Other staff portals remain a specification; they are not implemented.
5. **Abuse protection:** public intake and authenticated complaint submission still require server-side validation, rate limiting, and abuse monitoring.
6. **Production release controls:** no verified staging deployment, backup/restore rehearsal, or production approval evidence exists.

## Release decision

**NOT APPROVED for production deployment.** The package has passed the listed static source checks, but security acceptance requires staging execution and real-role tests. Keep PR #1 in draft and do not merge or deploy based on this report.

No Supabase data, policies, grants, or production services were changed by this static review.
