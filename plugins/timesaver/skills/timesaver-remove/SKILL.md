---
name: timesaver-remove
description: Use /timesaver-remove to remove MINDY TimeSaver and choose whether to keep your saved sessions.
user-invocable: true
---

Never use an em dash. Name no app the person is not in. First ask exactly: `Do you want to keep your saved sessions or delete them?` Stop and wait. Make no change until they answer clearly.

In the Claude app outside Local Code, do not remove files through the cloud shell or promise that the Mac engine has been removed. Say `Click the </> button, choose Local and type /timesaver-remove there to remove MINDY TimeSaver from this Mac.` Retain their keep or delete choice for that step and stop.

In a local session, run the plugin's absolute `scripts/bun-runtime.sh` path with `timesaver-install/runtime/remove.ts keep` or `timesaver-install/runtime/remove.ts delete`, matching their answer. In Claude Code, the app substitutes `${CLAUDE_PLUGIN_ROOT}`. In the ChatGPT app or Codex, obtain the absolute plugin path from this skill's location. Before this command in a restricted local session, request write access together for the recorded saves folder, its parent, the home folder's `.timesaver`, `.claude` and `.codex` folders, and the parent of every redirect recorded in `install-state.json`. In the ChatGPT app or Codex, use `request_permissions` with those folders if offered; otherwise run with `sandbox_permissions: "require_escalated"`. In Claude Code, disable the sandbox for this command. The reason is `Remove MINDY TimeSaver and update its app settings.` Example for keeping saves:

```sh
"${CLAUDE_PLUGIN_ROOT}/scripts/bun-runtime.sh" timesaver-install/runtime/remove.ts keep
```

For deletion, replace `keep` with `delete`. Never delete anything by hand on a failure.

Relay the result exactly. Removing the engine cannot remove a plugin from a Claude account. In the Claude app, then say: `Open Customize, then Plugins. Open MINDY TimeSaver, open its menu and choose Remove. Do the same for MINDY TimeSaver Setup. Disconnect your saves folder from this chat.` In Claude Code in the Terminal, say `Remove MINDY TimeSaver and MINDY TimeSaver Setup from your account's Plugins page too, if you added them there.` In the ChatGPT app or Codex, say `Remove MINDY TimeSaver and MINDY TimeSaver Setup from Plugins if they are still listed.` Never name another app. Do not claim removal is complete until the person has completed the account or app step. The shared mindy-plugin marketplace and unrelated plugins stay in place.
