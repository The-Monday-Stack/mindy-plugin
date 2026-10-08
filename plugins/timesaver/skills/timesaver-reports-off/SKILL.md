---
name: timesaver-reports-off
description: Use /timesaver-reports-off to stop sending MINDY TimeSaver bug reports.
---

Use commas, colons or full stops in every reply to the person. Never use an em dash, including in lists and save confirmations.

In the Claude app outside Local Code, say `Bug reports from this chat are not sent automatically.` and stop without running a local command.

In Claude Code, run the commands below as written: the app replaces `${CLAUDE_PLUGIN_ROOT}` in this skill's text with the installed plugin's absolute path before you see it. It is not a Bash environment variable. In the ChatGPT app and Codex, replace `${CLAUDE_PLUGIN_ROOT}` in each command with the absolute plugin path obtained by moving up two directories from the folder containing this `SKILL.md` supplied by the app. Run that quoted absolute command directly, without setting a shell variable or changing folders.

Run:

```sh
"${CLAUDE_PLUGIN_ROOT}/scripts/bun-runtime.sh" timesaver-install/runtime/privacy.ts reports-off
```

Relay the result exactly. This changes the setting for both apps and every folder. Nothing already saved is deleted. Do not read or save the session as part of this command.
