---
name: mindyhelp
description: Show the short how-to, explain what Mindy TimeSaver can do or move your saves folder. USE WHEN move my saves folder, move my TimeSaver folder, put my memories somewhere else.
user-invocable: true
---

Use commas, colons or full stops in every reply to the person. Never use an em dash.

When the person asks in plain words to move their saves folder, ask for the destination if they have not given it. In the Claude app outside Local Code, say exactly: `Click the </> button, choose Local and ask me to move your saves folder there.` Keep their destination for that step and stop. In a local session, run `"$HOME/.timesaver/plugin-marketplace/plugins/timesaver/scripts/bun-runtime.sh" timesaver-install/runtime/move.ts "<destination>"`. Request write permission for the current saves folder, its parent, the destination's parent and the home folder's `.timesaver` folder before running in a restricted session. The destination can be outside the home folder, on another disk or inside a cloud-synced folder. Its parent must be reachable. If the destination holds other files, the saves go in a timesaver folder inside it. A timesaver folder already there stops the move. The command waits for active workers. Relay its result exactly. Only in Local Code in the Claude app, append `Reconnect this folder on the chat side using its folder picker.` Stop without setup or saving. Never move the folder by hand.

If the person asks what Mindy TimeSaver can do, or chooses "show me what it can do", say exactly: `Mindy TimeSaver saves what you asked, decided and did, so your AI can pick up earlier work. Type /mindyend to save a session, /mindyload to bring earlier work into this conversation, or /mindysearch to find your saved memories. Your saves stay in your own folder on this Mac.` Stop without running a command or describing another app.

For /mindyhelp, show only these lines, exactly. Do not run a command or change anything.

Type /mindyend at the end of a session to save it.
Use /mindyload to give your AI all the context it needs for any work you've saved.
Use /mindysearch to search for anything in your MTS.
Use /mindyteam to send a bug report, give feedback or ask a question.
Use /mindyhelp for a reminder of these instructions.

<!-- MIKE'S WEBSITE AND OFFERS: BEGIN -->

<!-- MIKE'S WEBSITE AND OFFERS: END -->
