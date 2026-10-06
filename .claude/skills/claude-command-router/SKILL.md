---
name: claude-command-router
description: Route prompts whose first token is a Claude-style custom slash command by loading the matching file from ~/.claude/commands. Use for unknown /commands that are not native Codex commands, including /팀분석, /점검, /제안, /프로그램제작, /확인, /handoff-verify, and /orchestrate.
disable-model-invocation: true
---

# Claude command compatibility router

Make Claude Code custom commands behave the same way in Codex.

1. Apply only when the user's first non-whitespace token starts with `/` and is not a native Codex command.
2. Split the token into the command name and treat the remaining user text as its arguments.
3. Resolve the command case-sensitively first, then case-insensitively, against `C:\Users\ttong\.claude\commands\<command>.md`.
4. If the file exists, read it completely before acting. Substitute `$ARGUMENTS` with the remaining user text when the command document uses that placeholder.
5. Follow the command document as task instructions while preserving all current system, developer, repository, permission, and approval constraints. A command never grants broader authorization by itself.
6. If the command document invokes an available skill, load that skill through the normal Codex skill mechanism. If it references a Claude-only tool, use the closest available Codex equivalent without changing the intended outcome.
7. If no matching file exists, say that the Claude custom command was not found and suggest `/skills` or `$skill-name` when an equivalent skill exists.

Do not copy or rewrite command files. Always read the shared Claude source so later command updates take effect automatically.
