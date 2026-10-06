---
name: timesaver-install
description: Set up Mindy TimeSaver with your access code.
---

Use commas, colons or full stops in every reply to the person. Never use an em dash, including in setup replies.

In Claude Code, run the commands below as written: the app replaces `${CLAUDE_PLUGIN_ROOT}` in this skill's text with the installed plugin's absolute path before you see it. It is not a Bash environment variable. In the ChatGPT app and Codex, replace `${CLAUDE_PLUGIN_ROOT}` in each command with the absolute plugin path obtained by moving up two directories from the folder containing this `SKILL.md` supplied by the app. Run that quoted absolute command directly, without setting a shell variable or changing folders.

When the person asks in plain words to move their saves folder, ask for the destination if they have not given it. In the Claude app outside Local Code, say exactly: `Click the </> button, choose Local and ask me to move your saves folder there.` Keep their destination for that step and stop. In a local session, run `"$HOME/.timesaver/plugin-marketplace/plugins/timesaver/scripts/bun-runtime.sh" timesaver-install/runtime/move.ts "<destination>"`. Request write permission for the current saves folder, its parent, the destination's parent and the home folder's `.timesaver` folder before running in a restricted session. The destination can be outside the home folder, on another disk or inside a cloud-synced folder. Its parent must be reachable. If the destination holds other files, the saves go in a timesaver folder inside it. A timesaver folder already there stops the move. The command waits for active workers. Relay its result exactly. Only in Local Code in the Claude app, append `Reconnect this folder on the chat side using its folder picker.` Stop without setup or saving. Never move the folder by hand.

In the Claude app outside a Local Code session, do not run setup or ask for an access code. Say exactly: `Click the </> button and choose Local. Type /timesaver-install with your access code there. When setup finishes, return here and connect the timesaver folder in your home folder using the folder picker beside the message box.` Then stop. Never download the Mac engine onto the app's cloud machine.

If the person asks what Mindy TimeSaver can do, or chooses "show me what it can do", say exactly: `Mindy TimeSaver saves what you asked, decided and did, so your AI can pick up earlier work. Type /mindyend to save a session, /mindyload to bring earlier work into this conversation, or /mindysearch to find your saved memories. Your saves stay in your own folder on this Mac.` Stop without starting setup.

Before asking for or using an access code, follow these routes in order:

1. If the person has not given a code, run `"${CLAUDE_PLUGIN_ROOT}/scripts/timesaver-setup.sh" --setup-stage`. If it returns `chat-keeping`, continue at message 2 below without running setup or message 1.
2. If the person types `/timesaver-install help`, run `"${CLAUDE_PLUGIN_ROOT}/scripts/timesaver-setup.sh" --help`. Relay every line exactly and stop. `help` is never an access code.
3. Only when the person has not given a code, check whether `"$HOME/.timesaver/install-state.json"` is a file and `"$HOME/.timesaver/install-transaction.json"` is absent, the same finished-install check setup uses. When both are true, run `"${CLAUDE_PLUGIN_ROOT}/scripts/timesaver-setup.sh"` without a code. Relay every line exactly, including the already-installed line, and stop. Do not run setup again or ask about chat keeping. A supplied code always continues to the coded setup below, even when either file exists.
4. Otherwise, if the person has not given a code, say exactly one of these and stop.

`This needs your Mindy TimeSaver access code, which came in the message with your install steps. Type /timesaver-install, a space and your code, all on one line.`

With a code, run `"${CLAUDE_PLUGIN_ROOT}/scripts/timesaver-setup.sh" --code-on-stdin` with the code alone on standard input. In a Local Code session in the Claude desktop app, append `--account-plugin` so setup finishes without a Terminal command and does not install a second local Claude plugin. Setup installs the runtime wrapper used by `mindyend`, `mindyload` and `mindysearch`.

The script must run with network access and outside the sandbox: it downloads Mindy TimeSaver from Mindy TimeSaver's download server and saves it in the person's home folder, outside the current folder. Inside the sandbox it cannot reach the server, and it would then wrongly tell the person to check they are online. Never run it inside the sandbox first to see whether it works. Run it outside the sandbox from the first try, by your app's own way of doing that: in Claude Code, run the command with the sandbox disabled (`dangerouslyDisableSandbox: true`); in the ChatGPT app (Codex), make the one request the next paragraph describes. If your app will ask the person before it runs the command, first say exactly `Setup needs to reach the internet and save Mindy TimeSaver in your home folder. When your app asks, allow it this once.` If your app can run the command outside the sandbox without asking (Codex set to never ask or to full access, or Claude Code with no sandbox or in auto mode), just run it, without that sentence. Only if the person declines, do not run it, and say exactly `Setup needs that permission to install Mindy TimeSaver. Ask me again when you're ready.`

In the ChatGPT app (Codex), the app lets the command reach the internet and edit only the folders you ask for, and setup edits three folders in the person's home folder: `timesaver`, where Mindy TimeSaver goes; `.timesaver`, where setup keeps its runtime, access code and setup notes; and `.codex`, where setup adds Mindy TimeSaver to this app. Asking for fewer stops setup part way, and asking again for each missing folder means another stop each time. So make one request, before setup runs, for the internet and all of these folders together. Then request that permission without putting the code in the command or the reason. First, with one ordinary command inside the sandbox, which asks the person nothing, find the full path of the person's home folder and whether Claude Code is on this Mac too: `printf '%s\n' "$HOME"; command -v claude || :`. Its first line is `<home>`. A second line means Claude Code is on this Mac and setup adds Mindy TimeSaver to it as well, so `<home>/.claude` is a fourth folder in the same request. If `install-state.json` or `kept-saves.json` in `<home>/.timesaver` records a `contentRoot`, replace `<home>/timesaver-install` in the write request with that path and include its parent, plus the parent of each recorded redirect. Read those records with the app's file tools before requesting permissions. Setup keeps its temporary install and update folders beside the recorded saves folder when it is on another disk. The download and unpacking use the app's writable temporary folder. Then call the `request_permissions` tool once, with `{"network": {"enabled": true}, "file_system": {"write": ["<home>/timesaver-install", "<home>/.timesaver", "<home>/.codex"]}}`, adding `"<home>/.claude"` to that list when Claude Code is on this Mac. Say the sentence above about allowing it this once just before this call. The app then asks the person once to let it connect to the internet and edit those folders. Never ask for the folders one at a time. When the person allows it, run the setup command straight away, in the same turn, as an ordinary command with no `sandbox_permissions`. Only if the `request_permissions` tool is not offered to you, instead run the setup command once with escalated permissions (`sandbox_permissions: "require_escalated"`) and a one-line justification, such as `Install Mindy TimeSaver: download it and save it in the home folder.`, which never contains the code. When Codex is set to never ask or to full access, request nothing, give no `sandbox_permissions` and just run it, as the paragraph above says.

## Setup in three messages

Name no app the person is not in. Use "your chats", "the app" and "your AI" in replies. App names and technical details in these instructions are for routing, never for relaying. Determine the current app from the host's session context and tools, not from other apps installed on the Mac. `CLAUDECODE` identifies Claude Code; the host identifies whether it is in the Claude app, ChatGPT app or Codex. If the host gives no UI identity, use the verified command route for its harness; never invent a UI step.

### Message 1: welcome

Relay every line from a successful install exactly. Never print the code back. Append only the ending for the current app below, then stop the turn. Do not inspect chat keeping or show the how-to until the person replies to message 1.

- ChatGPT app: `Click the anchor icon at the bottom of the chat, then Allow all to approve Mindy TimeSaver's hooks. Let me know when you've done that.`
- Codex outside the ChatGPT app: `Open Plugins and choose Mindy TimeSaver. Scroll down to Hooks and click Trust all. Let me know when you've done that.`
- Claude Code in the Terminal: `Ready to choose how long to keep your chats?`
- Local Code in the Claude app: `Open Customize, then Plugins, and add timesaver from the mindy marketplace. Start a new session and type /timesaver-install to continue.`

The chat-side route above ends before the three setup messages. Account plugins sync at the next session start. Chat ignores hooks. The Code side runs locally only when Local is selected. Sources: https://claude.com/docs/plugins/platform-support.md and https://code.claude.com/docs/en/desktop-quickstart.

### Message 2: chat keeping

After the person confirms message 1, follow the chat-keeping section below for this app only, then stop the turn. Never show message 3 in this turn, including when there is nothing to change, settings cannot be changed or an organisation controls them. Where no choice is needed, end with `Ready for the short how-to?` and wait for the person.

### Message 3: short how-to

After the person's answer to message 2, apply their chat-keeping choice if needed, then always finish with the short how-to, even when they leave the setting alone or it cannot be changed. First run `"${CLAUDE_PLUGIN_ROOT}/scripts/timesaver-setup.sh" --folder-info` and relay its folder message. In the Claude app, also say `Connect this folder to your chat using the folder picker, and keep the desktop app open while using your saves.` The saves-folder message names Claude and ChatGPT by Mike's decision. Relay those names too. Then run `"${CLAUDE_PLUGIN_ROOT}/scripts/timesaver-setup.sh" --help` and relay every line exactly. This is also the how-to for `/mindyhelp`. Then run `"${CLAUDE_PLUGIN_ROOT}/scripts/timesaver-setup.sh" --setup-complete`.

<!-- MIKE'S WEBSITE AND OFFERS: BEGIN -->

<!-- MIKE'S WEBSITE AND OFFERS: END -->

If setup stops or fails, stop without asking about chat keeping. The already-installed route and explicit help route above show the short how-to and stop, without restarting the three messages.

## Ask how long to keep chats

Claude Code deletes each chat after 30 days unless its own settings say otherwise. Ask the person how long to keep them, and change nothing until they answer. This section runs at the end of setup, or when the person asks to change how long their chats are kept. This changes one Claude Code setting only. It does not change Mindy TimeSaver's own session memory, and it never opens, lists or names a chat.

Run the inspection and choice below only in Claude Code, including Code in the Claude app. Never change another app's settings because it is installed or the person also uses it. In the ChatGPT app and Codex, do not inspect or change Claude Code settings; say:

> The app already keeps your chats on this Mac, so your whole history with Mindy TimeSaver is there. Every upgrade to Mindy TimeSaver's memory can be run back over all of it. There's nothing to change.

In the Claude app outside Code, do not run the local chat-keeping utility. Say `This app controls how long your chats are kept. I cannot change that here.` and wait as message 2 requires.

Run this. It changes nothing:

```bash
"$HOME/.timesaver/plugin-marketplace/plugins/timesaver/scripts/bun-runtime.sh" MY-MIND/MY-SYSTEM/utilities/claude-chat-keeping.ts inspect --claude-dir "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
```

Read only the returned JSON:

- `settingsState` is `invalid`: do not ask and change nothing. Say: `The app's settings file cannot be changed safely right now (<settingsProblem>), so I have left how long your chats are kept as it is.`
- `managedDays` is a number: do not ask and change nothing. Say: `Your organisation sets how long the app keeps chats (<managedDays> days), so Mindy TimeSaver cannot change it.`
- `keptForGood` is `true` during setup: do not ask and change nothing. In a change request, never skip: ask the question below. During setup, say: `The app already keeps your chats for good, which is what I recommend, so I have left it as it is. You can change this later by asking Mindy TimeSaver.`
- Otherwise ask the question below, with `<days>` replaced by `currentDays`.

> How long do you want to keep your chats?
>
> Every conversation you have with me is saved as a chat on this Mac. Together, those chats are the full record of your work with Mindy TimeSaver: what you were building, what you decided, what you tried and dropped, and why.
>
> Mindy TimeSaver's memory learns from that record, and it keeps getting better. Upgrades and improvements to it arrive all the time. Because your chats are kept, each upgrade isn't limited to what happens from that day on: it can be run back over your whole history, so Mindy TimeSaver understands your past work better every time it improves. That's how it comes to remember what you decided and committed to, notice what keeps coming up, and pick up where you left off, however long ago that was. It can only do this with chats that still exist.
>
> Right now the app deletes each chat after <days> days.
>
> So I recommend keeping them for good.
>
> <storage note>
>
> One thing to know: chats are saved as plain text on this Mac. They can include anything that passed through, such as the contents of a file or a password you pasted, so anyone who can open your Mac's files could read them. If that matters to you, choose a shorter time.
>
> 1. Keep them for good (recommended)
> 2. Keep them for a number of days you choose
> 3. Leave it as it is: deleted after <days> days
>
> You can change this any time by asking me.

When `keptForGood` is `true`, which happens only in a change request, make two replacements: `Right now the app deletes each chat after <days> days.` becomes `Right now the app keeps your chats for good.`; and option 3 becomes `3. Leave it as it is: kept for good`.

The storage note comes from the `storage` values in the returned JSON. When its `chats` count is more than 0, say this, with `last30Days` and `perYear` copied exactly. `perYear` already begins with `about`, so do not add another:

> Your chats from the last 30 days take up <last30Days>. At this pace, a year of chats would take <perYear>.

When its `chats` count is 0, say:

> There are no chats from the last 30 days to measure yet. Chats are saved as text, so they take far less space than photos or video.

Only after the person answers:

- Keep them for good: run the command below with `--for-good`, then say: `Done. The app will now keep your chats for good. It has no setting for never, so I set it to 100 years.`
- A number of days: if they have not given one, ask how many. It must be a whole number from 1 to 36500. If it is below `currentDays`, first say `Choosing <N> days deletes every chat older than that the next time the app starts, and they cannot come back. Do you still want <N> days?`, with `<N>` their number, and continue only if they say yes; otherwise run nothing and say `I have left it as it is.` Run the command below with `--days <their number>`, then say: `Done. The app will now keep each chat for <days> days.`, with `<days>` taken from the returned `days`.
- Leave it as it is, or no clear answer: run nothing and say: `I have left it as it is.`

```bash
"$HOME/.timesaver/plugin-marketplace/plugins/timesaver/scripts/bun-runtime.sh" MY-MIND/MY-SYSTEM/utilities/claude-chat-keeping.ts apply --claude-dir "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" --for-good
```

The command sets only `cleanupPeriodDays` in Claude Code's own settings file and keeps every other setting exactly as it was. If it stops, nothing was changed: show its complete error, and do not edit the settings file by hand.

If the person later asks Mindy TimeSaver to change how long chats are kept, follow this section again from the inspection as a change request. Do not change it without their answer.
