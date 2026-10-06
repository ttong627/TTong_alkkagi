---
description: '코드맵 갱신 — 소스 구조·의존성을 훑어 codemaps/ 아키텍처 문서를 최신으로 고친다. 큰 리팩터·새 모듈 뒤에 쓴다.'
---

# Update Codemaps

Analyze the codebase structure and update architecture documentation:

1. Scan all source files for imports, exports, and dependencies
2. Generate token-lean codemaps in the following format:
   - codemaps/architecture.md - Overall architecture
   - codemaps/backend.md - Backend structure  
   - codemaps/frontend.md - Frontend structure
   - codemaps/data.md - Data models and schemas

3. Calculate diff percentage from previous version
4. If changes > 30%, list what changed first in the report, then update (형 규칙: 기다리지 않고 진행)
5. Add freshness timestamp to each codemap
6. Save reports to .reports/codemap-diff.txt

Use TypeScript/Node.js for analysis. Focus on high-level structure, not implementation details.
