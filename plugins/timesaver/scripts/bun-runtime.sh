#!/bin/sh
set -eu

[ -n "${HOME:-}" ] || { printf '%s\n' 'Mindy TimeSaver cannot find this Mac home folder.' >&2; exit 1; }

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export MTS_PRODUCT=mts
export MTS_STATE_ROOT="${MTS_STATE_ROOT:-$HOME/.timesaver}"
export MTS_RUNTIME_SCRATCH_DIR="${MTS_RUNTIME_SCRATCH_DIR:-$MTS_STATE_ROOT/runtime-scratch}"

bun="$MTS_STATE_ROOT/bin/bun"
[ -f "$bun" ] && [ ! -L "$bun" ] && [ -x "$bun" ] || { printf '%s\n' 'Mindy TimeSaver setup has not finished on this Mac. Type /timesaver-install with your access code.' >&2; exit 1; }

content_root=${MTS_CONTENT_ROOT:-}
if [ -z "$content_root" ] && [ -f "$MTS_STATE_ROOT/install-state.json" ]; then
 content_root=$(cd "$MTS_STATE_ROOT" && "$bun" -e 'const state = await Bun.file(process.argv[1]).json(); process.stdout.write(typeof state.contentRoot === "string" ? state.contentRoot : process.env.HOME + "/timesaver");' "$MTS_STATE_ROOT/install-state.json")
fi
if [ -z "$content_root" ]; then
 printf '%s\n' 'Mindy TimeSaver setup has not finished on this Mac. Type /timesaver-install with your access code.' >&2
 exit 1
fi
folder_unreachable() {
 printf '%s\n' 'MTS_SAVE_REFUSED' "Mindy TimeSaver cannot reach your saves folder at $content_root. Reconnect its disk or cloud folder, then try again. Your existing saves have not been changed." >&2
 exit 1
}
if [ ! -d "$content_root" ]; then folder_unreachable; fi
if [ ! -r "$content_root/timesaver.json" ]; then
 printf '%s\n' 'MTS_SAVE_REFUSED' "Mindy TimeSaver's engine needs updating. Type /timesaver-install with your access code." >&2
 exit 1
fi
if MTS_CONTENT_ROOT=$(CDPATH= cd -- "$content_root" 2>/dev/null && pwd); then :; else folder_unreachable; fi
export MTS_CONTENT_ROOT
cd "$MTS_CONTENT_ROOT"

# Setting commands and session start run even while saving is off.
# Manual writers need the app's session id. The worker needs only the current setting.
case "${1:-}" in
 */privacy.ts|*/session-start.ts|timesaver-install/runtime/read-memory.ts|timesaver-install/runtime/remove.ts|timesaver-install/runtime/move.ts|MY-MIND/MY-SYSTEM/utilities/mindy-search.ts|MY-MIND/MY-SYSTEM/utilities/claude-chat-keeping.ts|bin/save-failure.ts) ;;
 *)
  if [ "${2:-}" = --quote-labels ] && [ "$#" -eq 2 ]; then :; else
   case "${1:-}" in
    *timesaver-capture-worker.ts) gate=check ;;
    *) gate=save-check ;;
   esac
   if [ "$gate" = check ]; then
    if "$bun" "$MTS_CONTENT_ROOT/timesaver-install/runtime/privacy.ts" check ""; then :; else
     status=$?
     case "$status" in 2) exit 0 ;; *) exit 1 ;; esac
    fi
   else
    if "$bun" "$MTS_CONTENT_ROOT/timesaver-install/runtime/privacy.ts" save-check "$@"; then :; else
     status=$?
     case "$status" in 2) exit 0 ;; *) exit 1 ;; esac
    fi
   fi
  fi
 ;;
esac
case "${1:-}" in
 MY-MIND/MY-SYSTEM/utilities/transcript.ts)
  exec "$bun" timesaver-install/runtime/privacy.ts save-run "$@" ;;
 *) exec "$bun" "$@" ;;
esac
