create index if not exists partners_created_by_idx on public.partners(created_by);

revoke execute on function public.get_public_aid_request_status(text) from public, authenticated;
grant execute on function public.get_public_aid_request_status(text) to anon;
revoke execute on function public.get_public_donation_receipt(text) from public, authenticated;
grant execute on function public.get_public_donation_receipt(text) to anon;
revoke execute on function public.get_public_impact_summary() from public, authenticated;
grant execute on function public.get_public_impact_summary() to anon;
revoke execute on function public.list_public_campaigns() from public, authenticated;
grant execute on function public.list_public_campaigns() to anon;
revoke execute on function public.list_public_confirmed_donations() from public, authenticated;
grant execute on function public.list_public_confirmed_donations() to anon;
revoke execute on function public.submit_public_aid_request(text,text,text,text,text,integer,integer,integer,integer,text,text,text,boolean) from public, authenticated;
grant execute on function public.submit_public_aid_request(text,text,text,text,text,integer,integer,integer,integer,text,text,text,boolean) to anon;
revoke execute on function public.submit_public_volunteer_interest(text,text,text,text) from public, authenticated;
grant execute on function public.submit_public_volunteer_interest(text,text,text,text) to anon;
revoke execute on function public.admin_list_public_aid_requests() from public, anon;
grant execute on function public.admin_list_public_aid_requests() to authenticated;
