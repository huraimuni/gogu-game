-- ============================================================
--  고구마 굽기 데이터 정리 (내일의 부자들 프로젝트에서 고구마 것만 삭제)
--  ※ 고구마 새 프로젝트가 정상 동작하는 것을 확인한 뒤에만 실행하세요.
--  ※ 이름이 gogu_ 로 시작하는 테이블·함수만 지웁니다. 되돌릴 수 없어요.
--  ※ 로그인 회원(auth.users)과 부자게임 테이블은 건드리지 않습니다.
-- ============================================================
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like 'gogu\_%' loop
    execute 'drop function if exists ' || r.sig || ' cascade';
  end loop;
  for r in select tablename from pg_tables where schemaname = 'public' and tablename like 'gogu\_%' loop
    execute 'drop table if exists public.' || quote_ident(r.tablename) || ' cascade';
  end loop;
end $$;
notify pgrst, 'reload schema';
