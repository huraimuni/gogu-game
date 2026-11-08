-- 내 링크를 눌러 준 횟수만큼 슈퍼장작 쿠폰 적립 (하루가 지나도 보관, 접속하면 받아가요)
alter table public.gogu_profiles add column if not exists link_coupons int not null default 0;

create or replace function public.gogu_link_click(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); today date := (now() at time zone 'Asia/Seoul')::date;
  sh public.gogu_profiles; got int := 0;
begin
  if uid is null then raise exception 'login required'; end if;
  perform public.gogu_ensure_profile();
  select * into sh from public.gogu_profiles where code = upper(btrim(coalesce(p_code, '')));
  if not found then raise exception '없는 링크예요'; end if;
  if sh.id = uid then raise exception '내 링크는 내가 눌러도 받을 수 없어요'; end if;
  if exists (select 1 from public.gogu_profiles where id = uid and flag_state = 'banned') then raise exception '이용할 수 없는 계정이에요'; end if;
  begin
    insert into public.gogu_link_claims(day, sharer, clicker) values (today, sh.id, uid);
  exception when unique_violation then
    raise exception '오늘 이 링크는 이미 눌렀어요. 내일 또 눌러 주세요';
  end;
  insert into public.gogu_daily(user_id, day) values (uid, today) on conflict do nothing;
  insert into public.gogu_daily(user_id, day) values (sh.id, today) on conflict do nothing;
  update public.gogu_daily set gave = gave + 1 where user_id = uid and day = today;
  perform public.gogu_add_butter_s(uid, 10); got := 10;                    -- 누른 사람: 슈퍼장작 10초
  update public.gogu_daily set recv = recv + 1 where user_id = sh.id and day = today;
  update public.gogu_profiles set link_coupons = link_coupons + 1 where id = sh.id;   -- 공유한 사람: 쿠폰 1장
  return jsonb_build_object('seconds', got, 'sharer', sh.nickname);
end $$;

create or replace function public.gogu_claim_link_coupons() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  update public.gogu_profiles p set link_coupons = 0
    from (select id, link_coupons from public.gogu_profiles where id = auth.uid() for update) o
    where p.id = o.id returning o.link_coupons into n;
  return coalesce(n, 0);
end $$;

revoke all on function public.gogu_link_click(text) from public, anon;
grant execute on function public.gogu_link_click(text) to authenticated;
revoke all on function public.gogu_claim_link_coupons() from public, anon;
grant execute on function public.gogu_claim_link_coupons() to authenticated;
notify pgrst, 'reload schema';
