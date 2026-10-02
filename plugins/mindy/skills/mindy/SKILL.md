---
name: mindy
description: Use when the person says /mindy, @mindy, install MINDY, set up MINDY, or my MINDY access code.
---

If the person has not given a code, say exactly one of these and stop.

In Claude Code: `This needs your MINDY access code, which came in the message with your install steps. Type /mindy, a space and your code, all on one line.`

In the ChatGPT app (Codex): `This needs your MINDY access code, which came in the message with your install steps. Type @mindy, a space and your code, all on one line.`

With a code, the script reads it from standard input, so the code never appears in its arguments. Run this through the ordinary shell tool as one command of three lines, with the code alone on the middle line, and relay its sentences:

```
<script> --code-on-stdin <<'MINDY_CODE'
<code>
MINDY_CODE
```

In Claude Code, `<script>` is `${CLAUDE_PLUGIN_ROOT}/scripts/mindy-setup.sh`.

In the ChatGPT app (Codex), this skill's `SKILL.md` was given to you by its absolute path, and the plugin folder is two levels above the `mindy` skill folder, so `<script>` is `<plugin folder>/scripts/mindy-setup.sh`.

The script must run with network access and outside the sandbox: it downloads MINDY from MINDY's download server and saves it in the person's home folder, outside the current folder. Inside the sandbox it cannot reach the server, and it would then wrongly tell the person to check they are online. Never run it inside the sandbox first to see whether it works. Run it outside the sandbox from the first try, by your app's own way of doing that: in Claude Code, run the command with the sandbox disabled (`dangerouslyDisableSandbox: true`); in the ChatGPT app (Codex), run the command with escalated permissions (`sandbox_permissions: "require_escalated"`) and a one-line justification, such as `Install MINDY: download it and save it in the home folder.`, which never contains the code. If your app will ask the person before it runs the command, first say exactly `Setup needs to reach the internet and save MINDY in your home folder. When your app asks, allow it this once.` If your app can run the command outside the sandbox without asking (Codex set to never ask or to full access, or Claude Code with no sandbox or in auto mode), just run it, without that sentence. Only if the person declines, do not run it, and say exactly `Setup needs that permission to install MINDY. Ask me again when you're ready.`

When the script stops, relay every line it printed, exactly as printed and in order.

When the script's sentence is `MINDY is now in <folder>`, relay it, then say the four lines under your app's heading below, exactly, one per line, and nothing else.

In Claude Code:

Next, quit this session, open Terminal, and type these two lines one at a time:
cd ~/mindy
claude
Then type /mindy:MYSETUP

<!-- The ChatGPT app (Codex) next step below is not yet confirmed by a laptop test. Change only its four lines. -->
In the ChatGPT app (Codex):

Next, open your MINDY folder as a project in this app:
Choose a project, then choose the mindy folder in your home folder
Start a new chat in that project, with Work and Local selected
Then type @MYSETUP and choose MYSETUP

<!-- End of the ChatGPT app (Codex) next step. -->
Never print the code back. Never read or change any other folder.
