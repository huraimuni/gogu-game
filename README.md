# 고구마 굽기

추억의 붕어빵게임이여 돌아와라!!

기존 붕어빵게임 서비스 종료의 아쉬움을 달래기 위해 만든 개인 제작 방치형 게임입니다. 당근마켓과 관련 없으며 그림과 이름은 모두 새로 만들었습니다.

## 서버 설정 (한 번만)
1. Supabase SQL Editor에서 `supabase/schema.sql` 전체를 실행합니다.
2. `config.js`에 프로젝트 주소(URL)와 공개(anon) 키를 넣습니다.
3. Supabase → Authentication → Providers → Kakao 를 켭니다 (REST API 키 / Client Secret).
4. 첫 로그인 후 SQL Editor에서 운영자 지정: `update gogu_profiles set is_admin = true where code = '내 코드';`

모든 테이블·함수 이름은 `gogu_` 로 시작해 다른 앱과 섞이지 않습니다.

## 스킨
- 고구마 / 화로 / 불 3칸, 무료 / 유료 / 이벤트 3등급 (`skins.js`).
- 유료·이벤트 스킨은 `supabase/skins.sql`을 SQL Editor에서 한 번 실행하면 등록되고, 운영자 페이지에서 코드로 지급합니다.
