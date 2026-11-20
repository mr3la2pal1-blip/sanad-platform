alter table public.announcements
  add column if not exists image_url text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'announcements_image_url_safe'
      and conrelid = 'public.announcements'::regclass
  ) then
    alter table public.announcements
      add constraint announcements_image_url_safe
      check (image_url is null or image_url ~* '^https?://');
  end if;
end
$$;
