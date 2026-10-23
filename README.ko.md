# DoopBox

**오픈소스 [Doop](https://github.com/kgoedecke/doop)을 내 Mac에서 로컬로, 데스크톱 앱처럼 실행**

[English](README.md) · **한국어**

> 비공식 커뮤니티 프로젝트입니다. Doop과 제휴 관계가 아니며 Doop의 승인을 받지 않았습니다.

DoopBox는 Doop을 내 Mac에서 로컬로 실행해서, 마치 데스크톱 앱처럼 쓸 수 있게 해 주는 앱입니다. 앱을 열면 Doop이 시작되고, 종료하면 멈춥니다. 첫 설정, 업데이트, 백업도 대신 처리합니다.

Doop에는 [공식 데스크톱 앱](https://github.com/kgoedecke/doop/releases)도 있습니다. 공식 앱은 호스팅 서비스(doop.design)를 여는 방식이고, DoopBox는 Doop의 오픈소스 버전을 내 Mac에서 직접 실행하는 방식입니다.

## 설치

1. [Releases](https://github.com/kimmojae/doopbox/releases)에서 최신 `DoopBox-<버전>.dmg`를 내려받아 열고, DoopBox를 Applications로 끌어다 놓습니다.
2. 공증을 받지 않은 앱이라 처음에는 macOS가 실행을 막습니다. 한 번 열어 본 뒤 **시스템 설정 → 개인정보 보호 및 보안**에서 **그래도 열기**를 누르세요. 또는 터미널에서 아래 명령을 한 번 실행해도 됩니다.

   ```bash
   xattr -dr com.apple.quarantine /Applications/DoopBox.app
   ```

macOS 14 이상과 Node.js 22 이상, git이 필요합니다. 백업과 업데이트는 설정(⌘,)에서 합니다.

## 라이선스

이 저장소의 코드는 [MIT](LICENSE)입니다. Doop은 AGPL-3.0을 따르는 별개의 프로젝트이며 포함되어 있지 않습니다. DoopBox는 첫 실행 때 Doop 공식 저장소에서 내려받습니다. "Doop" 이름과 로고는 소유자의 것으로 위 두 라이선스 어느 쪽의 적용 대상도 아닙니다. 문제가 된다면 조치를 취하거나 삭제하겠습니다.
