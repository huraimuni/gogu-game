# 고구마 굽기

개인 제작 방치형 게임입니다. 당근마켓과 관련 없으며 그림과 이름은 모두 새로 만들었습니다.

## 서버 설정 (한 번만)
1. Supabase SQL Editor에서 `supabase/schema.sql` 전체를 실행합니다.
2. `config.js`에 프로젝트 주소(URL)와 공개(anon) 키를 넣습니다.
3. Supabase → Authentication → Providers → Kakao 를 켭니다 (REST API 키 / Client Secret).
4. 첫 로그인 후 SQL Editor에서 운영자 지정: `update gogu_profiles set is_admin = true where code = '내 코드';`

모든 테이블·함수 이름은 `gogu_` 로 시작해 다른 앱과 섞이지 않습니다.

## 스킨
- 고구마 / 화로 / 불 3칸, 무료 / 유료 / 이벤트 3등급 (`skins.js`).
- 유료·이벤트 스킨은 `supabase/skins.sql`을 SQL Editor에서 한 번 실행하면 등록되고, 운영자 페이지에서 코드로 지급합니다.

## 운영 기능 (터치 검사 · 제재 · 운영자 · 신청 · 기간제 · 룰렛 · 친구)
- `supabase/ops.sql` 을 SQL Editor에서 한 번 실행합니다 (schema.sql 실행 후, 스킨 등록 포함, 여러 번 실행해도 안전).
- 운영자 페이지(`admin.html`): 지급 / 제재(일괄 처리) / 신청(일괄 승인) / 운영자 지정(대표만).
- 규정: 의심 패턴 → 랭킹 보류·안내 → 이의 신청 → 해명 인정 시 경고 1회 후 해제 → 같은 시즌 재발 시 영구 제외(대표만 확정).
