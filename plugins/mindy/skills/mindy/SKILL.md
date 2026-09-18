---
name: mindy
description: Use when the person says /mindy, install Mindy, set up Mindy, or my code from Mike.
---

If the person has not given a code, say exactly `This needs your access code from Mike.` and stop.

With a code, in Claude Code run `${CLAUDE_PLUGIN_ROOT}/scripts/mindy-setup.sh --code <code>` through the ordinary shell tool and relay its sentences.

In Codex, this skill's `SKILL.md` was given to you by its absolute path, and the plugin folder is two levels above the `mindy` skill folder, so run `<plugin folder>/scripts/mindy-setup.sh --code <code>` through the ordinary shell tool and relay its sentences.

Never print the code back. Never read or change any other folder.
