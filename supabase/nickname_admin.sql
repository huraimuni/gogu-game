-- 닉네임 규칙: 일반 유저 2~10자·30일 1회, 대표 운영자만 1~10자·횟수 제한 없음
create or replace function public.gogu_set_nickname(p_name text) returns text
language plpgsql security definer set search_path = public as $$
declare p public.gogu_profiles; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'login required'; end if;
  p_name := btrim(coalesce(p_name, ''));
  select * into p from public.gogu_profiles where id = uid;
  if not found then raise exception 'no profile'; end if;
  if p_name !~ (case when p.is_admin then '^[가-힣A-Za-z0-9_]{1,10}$' else '^[가-힣A-Za-z0-9_]{2,10}$' end) then
    raise exception '닉네임은 한글·영문·숫자 2~10자예요';
  end if;
  if p.nickname = p_name then return p.nickname; end if;
  if p.nickname_changed_at is not null and now() - p.nickname_changed_at < interval '30 days' and not p.is_admin then
    raise exception '닉네임은 30일에 한 번만 바꿀 수 있어요';
  end if;
  begin
    update public.gogu_profiles set nickname = p_name, nickname_changed_at = now() where id = uid;
  exception when unique_violation then
    raise exception '이미 사용 중인 닉네임이에요';
  end;
  return p_name;
end $$;
revoke all on function public.gogu_set_nickname(text) from public, anon;
grant execute on function public.gogu_set_nickname(text) to authenticated;
