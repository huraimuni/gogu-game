-- 튜토리얼/규칙 확인 기록 (기존 회원은 null → 다음 접속 때 1회 노출)
alter table public.gogu_profiles add column if not exists rules_ack_at timestamptz;

create or replace function public.gogu_rules_status() returns boolean
language plpgsql security definer set search_path = public as $$
declare v timestamptz; f boolean;
begin
  if auth.uid() is null then return false; end if;
  select rules_ack_at, true into v, f from public.gogu_profiles where id = auth.uid();
  return coalesce(f, false) and v is null;
end $$;

create or replace function public.gogu_rules_ack() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  update public.gogu_profiles set rules_ack_at = coalesce(rules_ack_at, now()) where id = auth.uid();
end $$;

revoke all on function public.gogu_rules_status() from public, anon;
revoke all on function public.gogu_rules_ack() from public, anon;
grant execute on function public.gogu_rules_status() to authenticated;
grant execute on function public.gogu_rules_ack() to authenticated;
notify pgrst, 'reload schema';
