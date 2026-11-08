# 백업 · 복구 안내

## 자동 백업
- GitHub Actions `데이터 백업 (매일)` 이 매일 새벽 3:30(한국시간)에 실행됩니다.
- 결과물은 **암호화**되어 해당 실행 화면 하단 `Artifacts > gogu-backup` 에 30일간 남습니다.
  (저장소가 공개라서 암호화하지 않은 백업은 절대 올리지 않습니다.)
- 이 작업이 매일 서버에 요청을 보내므로 무료 서버의 "일주일 무접속 정지"도 막아 줍니다.

## 처음 한 번 설정 (저장소 Settings > Secrets and variables > Actions > New repository secret)
1. `SUPABASE_DB_URL`
   - Supabase 대시보드 > gogu-game > 위쪽 `Connect` > `Session pooler` 의 연결 문자열
   - `[YOUR-PASSWORD]` 자리에 DB 비밀번호를 넣어 붙여 넣으세요.
   - 반드시 **pooler 주소**(…pooler.supabase.com)를 쓰세요. 직접 연결 주소는 GitHub 서버에서 안 붙을 수 있어요.
   - DB 비밀번호를 모르면 Project Settings > Database > Reset database password.
2. `BACKUP_PASSPHRASE`
   - 백업 암호. 길고 아무도 모르는 문장으로 정하고 **따로 안전한 곳(비밀번호 관리자 등)에 보관**하세요.
   - 이 암호를 잃으면 백업을 열 수 없습니다.
3. Actions 탭 > `데이터 백업 (매일)` > `Run workflow` 로 한 번 돌려서 초록색 성공을 확인하세요.

## 복구 방법
```
gpg --decrypt gogu-backup-날짜.sql.gz.gpg | gunzip > dump.sql
psql "새 프로젝트의 연결 문자열" -f dump.sql
```
- 먼저 `schema.sql`, `ops.sql` 로 빈 서버를 만든 뒤 데이터만 넣거나, 비어 있는 새 프로젝트에 dump.sql 전체를 넣습니다.

## 보안 메모
- 백업에는 유저의 카카오 로그인 식별 정보(auth 스키마)가 들어 있습니다. 암호화 상태로만 보관하고, 복호화한 파일은 쓰고 나서 지우세요.
