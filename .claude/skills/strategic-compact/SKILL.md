---
name: strategic-compact
description: "대화 압축 시점 판단 — 작업 덩어리가 끝났을 때 /compact 나 /핸드오프 를 권할지 정한다. 「컨텍스트 압축」「대화가 길어」에 쓴다."
---

# Strategic Compact Skill

Suggests manual `/compact` at strategic points in your workflow rather than relying on arbitrary auto-compaction.

## Why Strategic Compaction?

Auto-compaction triggers at arbitrary points:
- Often mid-task, losing important context
- No awareness of logical task boundaries
- Can interrupt complex multi-step operations

Strategic compaction at logical boundaries:
- **After exploration, before execution** - Compact research context, keep implementation plan
- **After completing a milestone** - Fresh start for next phase
- **Before major context shifts** - Clear exploration context before different task

## How It Works (형 환경)

원문은 `suggest-compact.sh` 훅(Edit/Write 50회마다 알림)을 전제로 하지만 **형 환경에는 이 훅을 설치하지 않았다**
(형: 훅 대량 추가 싫음 · 2026-09-26 ECC 이식 때 제외). 아래 「언제 줄일까」 기준으로 **안토니가 직접 판단**한다.
- 한 덩어리 작업을 끝냈고 다음 덩어리가 다른 주제면 → `/compact` 를 형에게 한 줄로 권한다
- 대화가 매우 길고 이어서 할 일이 남았으면 → `/핸드오프` 로 HANDOFF.md 를 남기고 새 세션을 권한다

## Best Practices

1. **Compact after planning** - Once plan is finalized, compact to start fresh
2. **Compact after debugging** - Clear error-resolution context before continuing
3. **Don't compact mid-implementation** - Preserve context for related changes
4. **Read the suggestion** - The hook tells you *when*, you decide *if*

## Related

- [The Longform Guide](https://x.com/affaanmustafa/status/2014040193557471352) - Token optimization section
- Memory persistence hooks - For state that survives compaction
