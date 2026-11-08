-- 최초 접속 온보딩: 로그인 → 닉네임 설정 → 게임
alter table public.gogu_profiles add column if not exists nickname_set boolean not null default true;
alter table public.gogu_profiles alter column nickname_set set default false;

create or replace function public.gogu_onboard_status() returns boolean
language plpgsql security definer set search_path = public as $$
declare v boolean;
begin
  if auth.uid() is null then return false; end if;
  select not nickname_set into v from public.gogu_profiles where id = auth.uid();
  return coalesce(v, false);
end $$;

create or replace function public.gogu_onboard_nickname(p_name text) returns text
language plpgsql security definer set search_path = public as $$
declare p public.gogu_profiles; uid uuid := auth.uid(); prob text;
begin
  if uid is null then raise exception 'login required'; end if;
  p_name := btrim(coalesce(p_name, ''));
  select * into p from public.gogu_profiles where id = uid;
  if not found then raise exception 'no profile'; end if;
  if p_name !~ (case when p.is_admin then '^[가-힣A-Za-z0-9_]{1,10}$' else '^[가-힣A-Za-z0-9_]{2,10}$' end) then
    raise exception '닉네임은 한글·영문·숫자 2~10자예요';
  end if;
  if p.nickname <> p_name then
    prob := public.gogu_nick_problem(p_name);
    if prob is not null and not p.is_admin then raise exception '%', prob; end if;
    begin
      update public.gogu_profiles set nickname = p_name where id = uid;
    exception when unique_violation then
      raise exception '이미 사용 중인 닉네임이에요';
    end;
  end if;
  update public.gogu_profiles set nickname_set = true where id = uid;
  return p_name;
end $$;

revoke all on function public.gogu_onboard_status() from public, anon;
revoke all on function public.gogu_onboard_nickname(text) from public, anon;
grant execute on function public.gogu_onboard_status() to authenticated;
grant execute on function public.gogu_onboard_nickname(text) to authenticated;
notify pgrst, 'reload schema';
