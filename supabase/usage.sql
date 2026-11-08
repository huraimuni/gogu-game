-- 대표 운영자용: 가입자·활동 수와 무료 한도 대비 사용량
create or replace function public.gogu_admin_usage() returns jsonb
language plpgsql security definer set search_path = public as $$
declare day0 timestamptz := date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
begin
  if not public.gogu_is_admin() then raise exception 'forbidden'; end if;
  return jsonb_build_object(
    'users',      (select count(*) from public.gogu_profiles),
    'new_today',  (select count(*) from public.gogu_profiles where created_at >= day0),
    'new_7d',     (select count(*) from public.gogu_profiles where created_at >= now() - interval '7 days'),
    'active_1d',  (select count(*) from public.gogu_saves where updated_at >= now() - interval '1 day'),
    'active_7d',  (select count(*) from public.gogu_saves where updated_at >= now() - interval '7 days'),
    'active_30d', (select count(*) from public.gogu_saves where updated_at >= now() - interval '30 days'),
    'db_bytes',   pg_database_size(current_database()),
    'limit_mau',  50000,
    'limit_db',   524288000);
end $$;
revoke all on function public.gogu_admin_usage() from public, anon;
grant execute on function public.gogu_admin_usage() to authenticated;
notify pgrst, 'reload schema';
