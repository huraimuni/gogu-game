// 설치 조건용 최소 서비스워커: 아무 것도 저장하지 않고 항상 네트워크에서 받아요 (예전 버전이 남지 않음)
self.addEventListener("install",function(){self.skipWaiting()});
self.addEventListener("activate",function(e){e.waitUntil(self.clients.claim())});
self.addEventListener("fetch",function(){});
