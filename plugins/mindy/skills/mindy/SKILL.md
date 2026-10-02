---
name: mindy
description: Use when the person says /mindy, install MINDY, set up MINDY, or my code from Mike.
---

If the person has not given a code, say exactly `This needs your MINDY access code, which came in the message with your install steps. Type /mindy, a space and your code, all on one line.` and stop.

With a code, the script reads it from standard input, so the code never appears in its arguments. Run this through the ordinary shell tool as one command of three lines, with the code alone on the middle line, and relay its sentences:

```
<script> --code-on-stdin <<'MINDY_CODE'
<code>
MINDY_CODE
```

In Claude Code, `<script>` is `${CLAUDE_PLUGIN_ROOT}/scripts/mindy-setup.sh`.

In Codex, this skill's `SKILL.md` was given to you by its absolute path, and the plugin folder is two levels above the `mindy` skill folder, so `<script>` is `<plugin folder>/scripts/mindy-setup.sh`.

When the script stops, relay every line it printed, exactly as printed and in order.

When the script's sentence is `MINDY is now in <folder>`, relay it, then say these four lines exactly, one per line.

In Claude Code:

Next, quit this session, open Terminal, and type these two lines one at a time:
cd ~/mindy
claude
Then type /mindy:MYSETUP

In Codex:

Next, quit this session, open Terminal, and type these two lines one at a time:
cd ~/mindy
codex
Then type /mindy:MYSETUP

Never print the code back. Never read or change any other folder.
