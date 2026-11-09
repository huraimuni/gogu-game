-- 랭킹에서 닉네임을 눌러 보는 공개 프로필 (코드·보유 목록은 노출하지 않음, 상대가 프로필을 숨겼으면 닉네임만)
create or replace function public.gogu_public_profile(p_nickname text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid(); p public.gogu_profiles; r public.gogu_records; f public.gogu_friends;
        sv jsonb; sk jsonb := '{}'::jsonb; k text; v text; s int := public.gogu_season(); clan text; fs text := 'none';
begin
  if me is null then raise exception 'login required'; end if;
  select * into p from public.gogu_profiles where nickname = btrim(coalesce(p_nickname, ''));
  if not found or p.is_admin or p.flag_state = 'banned' then raise exception '찾을 수 없는 회원이에요'; end if;
  if p.id = me then fs := 'me';
  else
    select * into f from public.gogu_friends
      where least(from_user, to_user) = least(me, p.id) and greatest(from_user, to_user) = greatest(me, p.id);
    if found then fs := case when f.status = 'accepted' then 'friend' when f.from_user = me then 'sent' else 'received' end; end if;
  end if;
  if not p.show_profile then return jsonb_build_object('nickname', p.nickname, 'hidden', true, 'friend', fs); end if;
  select * into r from public.gogu_records where user_id = p.id and season = s;
  select data->'skin' into sv from public.gogu_saves where user_id = p.id;
  if sv is not null and jsonb_typeof(sv) = 'object' then
    foreach k in array array['p','b','f','g'] loop
      v := sv->>k;
      if v is not null and (v = any(public.gogu_free_skins()) or public.gogu_has_item(p.id, v)) then
        sk := sk || jsonb_build_object(k, v);
      end if;
    end loop;
  end if;
  select name into clan from public.gogu_clans where id = p.clan_id;
  return jsonb_build_object('nickname', p.nickname, 'title', p.title, 'clan', clan, 'skin', sk, 'friend', fs,
    'ps', case when p.flag_state in ('hold') then null else coalesce(r.best_ps, 0) end,
    'pc', case when p.flag_state in ('hold') then null else coalesce(r.best_pc, 1) end,
    'joined', p.created_at);
end $$;

-- 닉네임으로 친구 신청 (코드를 몰라도 되게) — 기존 gogu_friend_request 규칙을 그대로 따름
create or replace function public.gogu_friend_request_nick(p_nickname text) returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  select code into c from public.gogu_profiles where nickname = btrim(coalesce(p_nickname, '')) and not is_admin;
  if c is null then raise exception '찾을 수 없는 회원이에요'; end if;
  return public.gogu_friend_request(c);
end $$;

revoke all on function public.gogu_public_profile(text) from public, anon;
revoke all on function public.gogu_friend_request_nick(text) from public, anon;
grant execute on function public.gogu_public_profile(text) to authenticated;
grant execute on function public.gogu_friend_request_nick(text) to authenticated;
notify pgrst, 'reload schema';
