drop policy if exists partners_public_read on public.partners;
drop policy if exists partners_anon_read on public.partners;
drop policy if exists partners_authenticated_read on public.partners;
create policy partners_anon_read on public.partners
for select to anon using (is_published = true);
create policy partners_authenticated_read on public.partners
for select to authenticated using (
  is_published = true or public.current_app_role() = 'admin'
);

drop policy if exists announcements_read_published_or_admin on public.announcements;
drop policy if exists announcements_anon_read on public.announcements;
drop policy if exists announcements_authenticated_read on public.announcements;
create policy announcements_anon_read on public.announcements
for select to anon using (is_published = true);
create policy announcements_authenticated_read on public.announcements
for select to authenticated using (
  is_published = true or public.current_app_role() = 'admin'
);
