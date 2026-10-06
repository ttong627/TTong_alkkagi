---
allowed-tools: Bash(git:*)
description: 기본 브랜치(main/master 자동 판별)를 fast-forward 로만 당겨 온다. 작업 중 변경이 있으면 멈추고 알린다.
---

# /pull — 안전하게 당겨 오기 (2026-09-27 고침)

> 옛 판은 `git pull origin main` 고정(Gemma4 는 master)이었고, 맨 `git stash`/`git stash pop` 을 썼다.
> stash 는 모든 워크트리·다른 세션이 함께 쓰는 한 줄 더미라, 맨 `pop` 은 **남의 변경을 꺼낼 수 있다**. 쓰지 않는다.

## 1. 상태 확인

```bash
git branch --show-current
git status --short
BASE=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's#^origin/##'); [ -n "$BASE" ] || BASE=main
echo "기본 브랜치: $BASE"
```

- 커밋 안 된 변경이 있으면 **당기지 않고** 목록을 보여 준다. 내 변경이면 먼저 커밋(임시면 `wip:` 커밋)하고 다시 한다. 다른 세션 변경이면 건드리지 않는다.
- 이 세션이 앱이 만든 워크트리 안이면 `git pull` 대신 `sync_with_base_branch` 도구를 쓴다.

## 2. 당기기 (fast-forward 만)

```bash
git fetch origin
git pull --ff-only origin "$(git branch --show-current)"
```
- 비공개 저장소가 「Repository not found」면 다른 세션이 gh 계정을 바꾼 것 — 명령 앞에 `GH_TOKEN=$(gh auth token --user <계정>)`.
- fast-forward 가 안 되면(갈라짐) 병합·rebase 하지 말고 갈라진 커밋 수(`git rev-list --left-right --count HEAD...@{u}`)를 보고한다.

## 3. 보고

```
■ 당기기: <브랜치> — <최신 | N개 커밋 받음 | 갈라짐 L/R>
```
