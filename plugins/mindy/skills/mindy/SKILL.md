---
name: mindy
description: Use when the person says /mindy, install Mindy, set up Mindy, or my code from Mike.
---

If the person has not given a code, say exactly `This needs your access code from Mike.` and stop.

With a code, in Claude Code run `${CLAUDE_PLUGIN_ROOT}/scripts/mindy-setup.sh --code <code>` through the ordinary shell tool and relay its sentences.

In Codex, this skill's `SKILL.md` was given to you by its absolute path, and the plugin folder is two levels above the `mindy` skill folder, so run `<plugin folder>/scripts/mindy-setup.sh --code <code>` through the ordinary shell tool and relay its sentences.

When the script's sentence is `Mindy is now in <folder>`, relay it, then say these four lines exactly, one per line.

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
