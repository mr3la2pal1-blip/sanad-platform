create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 160),
  category text not null default 'community' check (category in ('community','institutional','business','media','other')),
  description text not null default '' check (length(description) <= 1200),
  website_url text,
  logo_url text,
  is_published boolean not null default false,
  display_order integer not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint partners_website_url_safe check (website_url is null or website_url ~* '^https?://'),
  constraint partners_logo_url_safe check (logo_url is null or logo_url ~* '^https?://')
);
alter table public.partners enable row level security;
grant select on public.partners to anon, authenticated;
grant insert, update, delete on public.partners to authenticated;
drop policy if exists partners_public_read on public.partners;
create policy partners_public_read on public.partners
for select to anon, authenticated using (
  is_published = true or public.current_app_role() = 'admin'
);
drop policy if exists partners_admin_insert on public.partners;
create policy partners_admin_insert on public.partners
for insert to authenticated with check (
  public.current_app_role() = 'admin' and (created_by is null or created_by = (select auth.uid()))
);
drop policy if exists partners_admin_update on public.partners;
create policy partners_admin_update on public.partners
for update to authenticated using (public.current_app_role() = 'admin')
with check (public.current_app_role() = 'admin');
drop policy if exists partners_admin_delete on public.partners;
create policy partners_admin_delete on public.partners
for delete to authenticated using (public.current_app_role() = 'admin');
