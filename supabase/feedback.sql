-- 버그 신고 · 기능 제안: 회원이 운영자에게 보내고, 운영자 페이지 '건의' 탭에서 확인
create table if not exists public.gogu_feedback(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('bug','idea','etc')),
  body text not null,
  ua text,
  status text not null default 'new' check (status in ('new','done')),
  created_at timestamptz not null default now()
);
create index if not exists gogu_feedback_created_idx on public.gogu_feedback(created_at desc);
alter table public.gogu_feedback enable row level security;
revoke all on public.gogu_feedback from anon, authenticated;

-- 보내기: 5~600자, 30초에 1건, 하루 5건까지
create or replace function public.gogu_feedback_send(p_kind text, p_body text, p_ua text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); b text := btrim(coalesce(p_body, ''));
begin
  if uid is null then raise exception 'login required'; end if;
  if not exists (select 1 from public.gogu_profiles where id = uid) then raise exception 'no profile'; end if;
  if exists (select 1 from public.gogu_profiles where id = uid and flag_state = 'banned') then raise exception '이용할 수 없는 계정이에요'; end if;
  if p_kind not in ('bug','idea','etc') then raise exception '종류를 골라 주세요'; end if;
  if char_length(b) < 5 then raise exception '내용을 5자 이상 적어 주세요'; end if;
  if char_length(b) > 600 then raise exception '내용은 600자까지 적을 수 있어요'; end if;
  if exists (select 1 from public.gogu_feedback where user_id = uid and created_at > now() - interval '30 seconds') then
    raise exception '조금 뒤에 다시 보내 주세요';
  end if;
  if (select count(*) from public.gogu_feedback where user_id = uid and created_at > now() - interval '24 hours') >= 5 then
    raise exception '하루에 5건까지 보낼 수 있어요';
  end if;
  insert into public.gogu_feedback(user_id, kind, body, ua) values (uid, p_kind, b, left(coalesce(p_ua, ''), 200));
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.gogu_feedback_send(text, text, text) from public, anon;
grant execute on function public.gogu_feedback_send(text, text, text) to authenticated;

-- 운영자: 목록 (새 글 먼저, 최근 100건)
create or replace function public.gogu_admin_feedback() returns table(
  id uuid, nickname text, code text, kind text, body text, ua text, status text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  perform public.gogu_require_op();
  return query
    select f.id, p.nickname, p.code, f.kind, f.body, f.ua, f.status, f.created_at
    from public.gogu_feedback f join public.gogu_profiles p on p.id = f.user_id
    order by (f.status = 'new') desc, f.created_at desc
    limit 100;
end $$;
revoke all on function public.gogu_admin_feedback() from public, anon;
grant execute on function public.gogu_admin_feedback() to authenticated;

-- 운영자: 확인 완료 처리 / 삭제
create or replace function public.gogu_admin_feedback_resolve(p_ids uuid[], p_action text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  perform public.gogu_require_op();
  if coalesce(array_length(p_ids, 1), 0) = 0 or array_length(p_ids, 1) > 200 then raise exception 'bad ids'; end if;
  if p_action = 'done' then
    update public.gogu_feedback set status = 'done' where id = any(p_ids);
  elsif p_action = 'delete' then
    delete from public.gogu_feedback where id = any(p_ids);
  else
    raise exception 'bad action';
  end if;
  get diagnostics n = row_count;
  return jsonb_build_object('done', n);
end $$;
revoke all on function public.gogu_admin_feedback_resolve(uuid[], text) from public, anon;
grant execute on function public.gogu_admin_feedback_resolve(uuid[], text) to authenticated;

notify pgrst, 'reload schema';
