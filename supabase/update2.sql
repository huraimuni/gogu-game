-- 업데이트 2: 룰렛 확률 하향 · 친구초대 3명째 스킨 7일권 · 닉네임 변경권/금칙어 필터
-- ① 룰렛 확률 (합계 10000 = 100%)
update public.gogu_roulette_prizes p set weight = v.w from (values
  ('포인트 5', 2000), ('포인트 10', 2636), ('포인트 30', 1900), ('포인트 100', 800),
  ('슈퍼장작 쿠폰 1장', 1500), ('슈퍼장작 쿠폰 3장', 600),
  ('이벤트 스킨 (7일, 무작위)', 450), ('이벤트 스킨 (30일, 무작위)', 50),
  ('유료 스킨 (7일, 무작위)', 50), ('유료 스킨 (30일, 무작위)', 10), ('유료 스킨 (90일, 무작위)', 3),
  ('선정 스킨 (영구)', 1)
) v(l, w) where p.label = v.l;

-- 붕어빵 전용 화로는 룰렛에서 제외
create or replace function public.gogu_roulette_spin() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); p public.gogu_profiles; today date := (now() at time zone 'Asia/Seoul')::date;
  total int; roll int; acc int := 0; pr public.gogu_roulette_prizes; skin public.gogu_items; gid uuid;
begin
  if uid is null then raise exception 'login required'; end if;
  select * into p from public.gogu_profiles where id = uid for update;
  if not found then raise exception 'no profile'; end if;
  if p.flag_state = 'banned' then raise exception '이용할 수 없는 계정이에요'; end if;
  if p.last_spin = today then raise exception '오늘은 이미 돌렸어요. 내일 또 도전하세요!'; end if;
  select sum(weight) into total from public.gogu_roulette_prizes;
  roll := 1 + floor(random() * total)::int;
  for pr in select * from public.gogu_roulette_prizes order by id loop
    acc := acc + pr.weight;
    if roll <= acc then exit; end if;
  end loop;
  if pr.kind in ('event_skin','paid_skin','featured_skin') then
    if pr.kind = 'featured_skin' then
      select i.* into skin from public.gogu_items i join public.gogu_settings st on st.key = 'featured_skin' and st.value = i.id where i.kind = 'skin';
    end if;
    if skin.id is null then
      -- 아직 없는 스킨을 먼저 고르고, 다 가졌으면 무작위 (선정 스킨이 없으면 유료 스킨 중에서)
      select * into skin from public.gogu_items where kind = 'skin' and tier = (case when pr.kind = 'event_skin' then 'event' else 'paid' end)
        and id <> 'skin_b_bungeo'
        order by public.gogu_has_item(uid, id), random() limit 1;
    end if;
    if skin.id is null then
      pr.kind := 'points'; pr.amount := 30; pr.label := '포인트 30';
    end if;
  end if;
  update public.gogu_profiles set last_spin = today where id = uid;
  insert into public.gogu_gifts(to_user, kind, item_id, amount, note, expires_at, item_days)
  values (uid, case when pr.kind in ('event_skin','paid_skin','featured_skin') then 'item' else pr.kind end,
          case when pr.kind in ('event_skin','paid_skin','featured_skin') then skin.id end,
          case when pr.kind not in ('event_skin','paid_skin','featured_skin') then pr.amount end,
          '룰렛 당첨', now() + interval '7 days', case when pr.kind in ('event_skin','paid_skin','featured_skin') then pr.item_days end)
  returning id into gid;
  return jsonb_build_object('gift_id', gid, 'label', case when pr.kind in ('event_skin','paid_skin','featured_skin') then skin.name || ' (' || coalesce(pr.item_days::text || '일', '영구') || ')' else pr.label end,
                            'kind', pr.kind);
end $$;

-- ② 친구 초대 3명째마다 랜덤 이벤트 스킨 7일권
create or replace function public.gogu_referral_skin(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare sid text;
begin
  select id into sid from public.gogu_items
   where kind = 'skin' and tier = 'event' and id <> 'skin_b_bungeo'
   order by public.gogu_has_item(p_user, id), random() limit 1;
  if sid is null then perform public.gogu_add_butter(p_user, 60); return; end if;
  insert into public.gogu_user_items(user_id, item_id, source, expires_at) values (p_user, sid, 'referral', now() + interval '7 days')
  on conflict (user_id, item_id) do update set expires_at =
    case when public.gogu_user_items.expires_at is null then null
         else greatest(public.gogu_user_items.expires_at, excluded.expires_at) end;
end $$;
revoke all on function public.gogu_referral_skin(uuid) from public, anon, authenticated;

create or replace function public.gogu_redeem_code(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); p public.gogu_profiles; norm text := upper(btrim(coalesce(p_code, '')));
  inv public.gogu_profiles; pr public.gogu_promos; it text; n int; names text[] := '{}'; nm text;
begin
  if uid is null then raise exception 'login required'; end if;
  p := public.gogu_ensure_profile();
  if p.flag_state = 'banned' then raise exception '이용할 수 없는 계정이에요'; end if;
  if norm = '' or length(norm) > 40 then raise exception '코드를 입력해 주세요'; end if;

  if norm like 'GOGU-%' then
    -- 친구 초대 코드
    select * into inv from public.gogu_profiles where code = norm;
    if not found then raise exception '없는 코드예요. 다시 확인해 주세요'; end if;
    if inv.id = uid then raise exception '내 코드는 쓸 수 없어요'; end if;
    if exists (select 1 from public.gogu_referrals where invitee = uid) then raise exception '이미 초대 코드를 사용했어요'; end if;
    if p.created_at < now() - interval '7 days' then raise exception '가입한 지 7일이 지난 계정은 쓸 수 없어요'; end if;
    select count(*) into n from public.gogu_referrals where inviter = inv.id and rewarded;
    insert into public.gogu_referrals(invitee, inviter, rewarded) values (uid, inv.id, n < 20);
    perform public.gogu_add_butter(uid, 30);
    if n < 20 then
      perform public.gogu_add_butter(inv.id, 30);
      if (n + 1) % 3 = 0 then perform public.gogu_referral_skin(inv.id); end if;
    end if;
    return jsonb_build_object('kind', 'referral', 'inviter', inv.nickname, 'minutes', 30);
  end if;

  -- 이벤트 초대 코드 (붕어빵)
  select * into pr from public.gogu_promos where norm = any(codes);
  if not found then raise exception '없는 코드예요. 다시 확인해 주세요'; end if;
  if pr.expires_at is not null and pr.expires_at <= now() then raise exception '기간이 지난 코드예요'; end if;
  begin
    insert into public.gogu_promo_redeems(user_id, promo_id) values (uid, pr.id);
  exception when unique_violation then
    raise exception '이미 사용한 코드예요';
  end;
  foreach it in array pr.items loop
    insert into public.gogu_user_items(user_id, item_id, source, expires_at) values (uid, it, 'promo', null)
    on conflict (user_id, item_id) do update set expires_at = null;
    select name into nm from public.gogu_items where id = it;
    names := names || coalesce(nm, it);
  end loop;
  perform public.gogu_add_butter(uid, pr.butter_min);
  return jsonb_build_object('kind', 'promo', 'label', pr.label, 'items', to_jsonb(names), 'minutes', pr.butter_min);
end $$;
revoke all on function public.gogu_redeem_code(text) from public, anon;
grant execute on function public.gogu_redeem_code(text) to authenticated;

-- ③ 닉네임: 변경권 + 금칙어/읽기 어려운 말 필터
alter table public.gogu_profiles add column if not exists nickname_tickets int not null default 0;

create or replace function public.gogu_nick_problem(p_name text) returns text
language plpgsql immutable as $$
declare
  n text := lower(regexp_replace(coalesce(p_name, ''), '[0-9_[:space:]]', '', 'g'));
  w text;
  bad text[] := array[
    '시발','씨발','씨팔','시팔','쉬발','씨바','시바','병신','븅신','지랄','좆','좇','존나','개새끼','미친놈','미친년',
    '꺼져','닥쳐','느금','니미','니애미','애미','엠창','걸레','창녀','창년','보지','자지','섹스','야동','포르노',
    '딸딸이','질싸','쌍년','쌍놈','씹','썅','한남','김치녀','된장녀','일베','메갈','틀딱','맘충','뒤져','뒈져','자살',
    'fuck','shit','bitch','dick','pussy','porn','sex','asshole','bastard','whore','slut','nigg','cunt','penis','vagina','rape','nazi'];
begin
  if n = '' then return '글자(한글·영문)를 포함해 주세요'; end if;
  foreach w in array bad loop
    if position(w in n) > 0 then return '사용할 수 없는 말이 들어 있어요. 다른 닉네임을 써 주세요'; end if;
  end loop;
  if coalesce(p_name, '') ~ '(.)\1{3,}' then return '같은 글자가 너무 많이 반복돼요'; end if;
  if n ~ '^[a-z]+$' and length(n) >= 5 and n !~ '[aeiouy]' then return '읽기 어려운 닉네임이에요. 읽을 수 있는 이름으로 지어 주세요'; end if;
  if n ~ '(asdf|qwer|zxcv|qazw|hjkl|uiop|wasd|asdg)' then return '읽기 어려운 닉네임이에요. 읽을 수 있는 이름으로 지어 주세요'; end if;
  return null;
end $$;

create or replace function public.gogu_set_nickname(p_name text) returns text
language plpgsql security definer set search_path = public as $$
declare p public.gogu_profiles; uid uuid := auth.uid(); prob text; use_ticket boolean := false;
begin
  if uid is null then raise exception 'login required'; end if;
  p_name := btrim(coalesce(p_name, ''));
  select * into p from public.gogu_profiles where id = uid;
  if not found then raise exception 'no profile'; end if;
  if p_name !~ (case when p.is_admin then '^[가-힣A-Za-z0-9_]{1,10}$' else '^[가-힣A-Za-z0-9_]{2,10}$' end) then
    raise exception '닉네임은 한글·영문·숫자 2~10자예요';
  end if;
  if p.nickname = p_name then return p.nickname; end if;
  prob := public.gogu_nick_problem(p_name);
  if prob is not null then raise exception '%', prob; end if;
  if p.nickname_changed_at is not null and not p.is_admin then
    if coalesce(p.nickname_tickets, 0) < 1 then
      raise exception '닉네임은 한 번만 바꿀 수 있어요. 닉네임 변경권이 있으면 다시 바꿀 수 있어요';
    end if;
    use_ticket := true;
  end if;
  begin
    update public.gogu_profiles
       set nickname = p_name, nickname_changed_at = now(),
           nickname_tickets = nickname_tickets - (case when use_ticket then 1 else 0 end)
     where id = uid;
  exception when unique_violation then
    raise exception '이미 사용 중인 닉네임이에요';
  end;
  return p_name;
end $$;
revoke all on function public.gogu_set_nickname(text) from public, anon;
grant execute on function public.gogu_set_nickname(text) to authenticated;

create or replace function public.gogu_nick_info() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('changed', nickname_changed_at is not null, 'tickets', nickname_tickets)
    from public.gogu_profiles where id = auth.uid();
$$;
revoke all on function public.gogu_nick_info() from public, anon;
grant execute on function public.gogu_nick_info() to authenticated;

-- 대표 운영자가 변경권을 지급 (결제 연결 전에는 수동 지급)
create or replace function public.gogu_admin_give_nick_ticket(p_code text, p_n int default 1) returns text
language plpgsql security definer set search_path = public as $$
declare nm text;
begin
  if not public.gogu_is_admin() then raise exception 'forbidden'; end if;
  if p_n is null or p_n < 1 or p_n > 20 then raise exception 'bad count'; end if;
  update public.gogu_profiles set nickname_tickets = nickname_tickets + p_n
   where code = upper(btrim(coalesce(p_code, ''))) returning nickname into nm;
  if nm is null then raise exception '없는 코드예요'; end if;
  return nm;
end $$;
revoke all on function public.gogu_admin_give_nick_ticket(text, int) from public, anon;
grant execute on function public.gogu_admin_give_nick_ticket(text, int) to authenticated;

notify pgrst, 'reload schema';
