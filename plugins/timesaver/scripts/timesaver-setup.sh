#!/bin/sh
set -eu

start='type /timesaver'
app_name='Claude Code'
if [ -z "${CLAUDECODE:-}" ] && [ -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}${CODEX_CLI_PATH:-}${CODEX_THREAD_ID:-}${CODEX_SANDBOX:-}" ]; then app_name='Codex'; fi
capital="$(printf '%s' "$start" | cut -c 1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$start" | cut -c 2-)"
no_code="This needs your Mindy TimeSaver access code, which came in the message with your install steps. $capital, a space and your code, all on one line."
not_issued="This is not a Mindy TimeSaver access code, so setup can't use it. Copy the code again in full from the message it came in, then $start with it."
not_active="This Mindy TimeSaver access code is no longer active, so it can't download Mindy TimeSaver."
different="This Mac already has a different Mindy TimeSaver access code saved, and Mindy TimeSaver uses one code per Mac. $capital with that earlier code."
unsigned="This download is not a signed Mindy TimeSaver release, so setup stopped before installing anything, to keep your Mac safe. Check you're on your usual internet connection, then $start with your access code again."
too_many="Too many tries from this internet connection in the last minute, so Mindy TimeSaver's download server is pausing for a moment. Wait a minute, then $start with your access code again."
unreachable="Setup could not reach Mindy TimeSaver's download server. Check you are online, then $start with your access code again."
interrupted="Setup stopped because it was interrupted. $capital with your access code to start again."
generic="Setup stopped before Mindy TimeSaver was installed. $capital with your access code to try again."

print_how_it_works() {
 printf '%s\n' "Mindy TimeSaver (MTS) is ready. It works in whatever folder you open $app_name in, and everything goes into one memory. Start a session with /mindyload, and type /mindyend when you finish to save it. Nothing will be saved to your MTS unless you type /mindyend at the end of a session. Each day, when you start a session, your MTS compresses the previous day's sessions into a summary. This also happens every week for days, every month for weeks, quarter for months and year for quarters."
 printf '%s\n' ""
 printf '%s\n' "To turn your TimeSaver off completely type /timesaver-off to stop saving and /timesaver-on to start again."
 printf '%s\n' ""
 printf '%s\n' "Don't forget - nothing at all will be saved to Mindy TimeSaver unless you type /mindyend at the end of a session!"
}

show_help() {
 print_how_it_works
 printf '%s\n' "Use /timesaver-reports-off to stop bug reports and /timesaver-reports-on to allow them again."
}
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then show_help; exit 0; fi
code=
if [ "${1:-}" = "--code-on-stdin" ]; then code=$(sed -n '1p' | tr -d ' \t\r') || code=; fi
if [ "$code" = "help" ]; then show_help; exit 0; fi
# An unfinished setup retains its transaction until app registration succeeds.
if [ -z "$code" ] && [ -f "$HOME/.timesaver/install-state.json" ] && [ ! -f "$HOME/.timesaver/install-transaction.json" ]; then
 printf '%s\n' "Mindy TimeSaver is already installed in $HOME/timesaver."
 show_help
 exit 0
fi
if [ -z "$code" ]; then printf '%s\n' "$no_code"; exit 0; fi

tmp=
finished=false
step='starting Mindy TimeSaver setup'
cleanup() { [ -z "$tmp" ] || rm -rf "$tmp"; }
on_signal() { trap - HUP INT TERM; finished=true; step='Mindy TimeSaver setup was interrupted'; report_stop "$interrupted" || :; cleanup; printf '%s\n' "$interrupted"; exit 1; }
on_exit() { status=$?; if [ "$status" != 0 ] && [ "$finished" = false ]; then report_stop "$generic" || :; fi; cleanup; if [ "$status" != 0 ] && [ "$finished" = false ]; then printf '%s\n' "$generic"; fi; }
trap on_signal HUP INT TERM
trap on_exit EXIT

gate_curl() {
	curl -H @/dev/fd/3 "$@" 3<<GATE_AUTHORIZATION
Authorization: Bearer $code
GATE_AUTHORIZATION
}

json_text() { printf '%s' "$1" | LC_ALL=C tr -d '\000-\010\013-\037\177' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$(printf '\t')/\\\\t/g"; }
report_stop() {
	[ -n "${home:-}" ] && [ -n "$code" ] || return 0
	stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf 'unknown-time')
	report_id="$(printf '%s' "$stamp" | tr ':' '-')-$$"
	stop_root="$home/.timesaver/setup-stops"
	note="$stop_root/$report_id.txt"
	if mkdir -p "$stop_root" 2>/dev/null; then
		chmod 700 "$home/.timesaver" "$stop_root" 2>/dev/null || :
		printf 'Mindy TimeSaver setup stop\nTime (UTC): %s\nStep: %s\nReason: %s\n' "$stamp" "$step" "$1" >"$note" 2>/dev/null || :
		chmod 600 "$note" 2>/dev/null || :
	fi
	membership_number=${code%.*}
	case "$membership_number" in ''|*[!A-Za-z0-9-]*) return 0 ;; esac
	[ "$membership_number" != "$code" ] || return 0
	report=$(printf '{"report":"mts-setup-stop/v1","product":"mts","reportId":"%s","membershipNumber":"%s","step":"%s","reason":"%s","stoppedAt":"%s"}' "$(json_text "$report_id")" "$(json_text "$membership_number")" "$(json_text "$step")" "$(json_text "$1")" "$(json_text "$stamp")")
	if printf '%s' "$report" | gate_curl -sS --connect-timeout 5 --max-time 10 -H 'Content-Type: application/json' --data-binary @- 'https://gate.mindy.build/mts/setup-stops' >/dev/null 2>&1; then :; fi
	return 0
}
fail_as() { finished=true; report_stop "$1" || :; printf '%s\n' "$1"; exit 1; }
tmp=$(mktemp -d) || fail_as "$generic"
plugin_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P) || fail_as "$generic"
home=${HOME:-}
[ -n "$home" ] || fail_as "$generic"
content_root="$home/timesaver"
state_root="$home/.timesaver"

packument="$tmp/packument.json"
step='asking Mindy TimeSaver download server for the latest release'
if status=$(gate_curl -sS -H 'Accept: application/json' -o "$packument" -w '%{http_code}' 'https://gate.mindy.build/mts' 2>/dev/null); then :; else fail_as "$unreachable"; fi
case "$status" in
	200) ;;
	403) if grep -qi 'no longer active\|expired\|revoked' "$packument"; then fail_as "$not_active"; else fail_as "$not_issued"; fi ;;
	429) fail_as "$too_many" ;;
	000) fail_as "$unreachable" ;;
	*) fail_as "$generic" ;;
esac
grep -q '"name"[[:space:]]*:[[:space:]]*"mts"' "$packument" || fail_as "$unsigned"
tags=$(sed -n 's/.*"dist-tags"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p' "$packument" | head -n 1)
version=$(printf '%s\n' "$tags" | sed -n 's/.*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
case "$version" in [0-9]*.[0-9]*.[0-9]*) ;; *) fail_as "$unsigned" ;; esac
entry=$(sed -n "s/.*\"$version\"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p" "$packument" | head -n 1)
integrity=$(printf '%s\n' "$entry" | sed -n 's/.*"integrity"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
case "$integrity" in sha512-*) ;; *) fail_as "$unsigned" ;; esac

archive="$tmp/mts.tgz"
step='downloading the Mindy TimeSaver release'
if status=$(gate_curl -sS -o "$archive" -w '%{http_code}' "https://gate.mindy.build/mts/-/mts-$version.tgz" 2>/dev/null); then :; else fail_as "$unreachable"; fi
[ "$status" = 200 ] || fail_as "$unreachable"
actual=$(shasum -a 512 "$archive" 2>/dev/null | sed 's/[[:space:]].*$//')
expected=$(printf '%s\n' "${integrity#sha512-}" | openssl base64 -d -A 2>/dev/null | od -An -tx1 | tr -d ' \n')
[ -n "$actual" ] && [ "$actual" = "$expected" ] || fail_as "$unsigned"
step='checking the download is a signed Mindy TimeSaver release'
entries="$tmp/archive-entries"
details="$tmp/archive-details"
[ "$(wc -c <"$archive" | tr -d ' ')" -le 262144000 ] || fail_as "$unsigned"
tar -tzf "$archive" >"$entries" 2>/dev/null || fail_as "$unsigned"
[ "$(wc -l <"$entries" | tr -d ' ')" -le 1024 ] || fail_as "$unsigned"
while IFS= read -r archive_entry; do
	case "$archive_entry" in ''|/*|../*|*/../*|*/..|*\\*) fail_as "$unsigned" ;; esac
done <"$entries"
tar -tvzf "$archive" >"$details" 2>/dev/null || fail_as "$unsigned"
if grep -Ev '^[-d]' "$details" >/dev/null 2>&1; then fail_as "$unsigned"; fi
awk '$1 ~ /^-/ { if ($5 !~ /^[0-9]+$/ || $5 > 209715200) exit 1; total += $5; if (total > 629145600) exit 1 }' "$details" || fail_as "$unsigned"

checked="$tmp/checked"
mkdir -p "$checked"
tar -xOf "$archive" package/release/release-signature.json >"$checked/release-signature.json" 2>/dev/null || fail_as "$unsigned"
tar -xOf "$archive" package/release/release-signature.sig >"$checked/release-signature.sig" 2>/dev/null || fail_as "$unsigned"
tar -xOf "$archive" package/release/release-manifest.json >"$checked/release-manifest.json" 2>/dev/null || fail_as "$unsigned"
key="$plugin_root/keys/timesaver-release-signature.pem"
[ -f "$key" ] || fail_as "$unsigned"
openssl dgst -sha256 -verify "$key" -signature "$checked/release-signature.sig" "$checked/release-signature.json" >/dev/null 2>&1 || fail_as "$unsigned"
grep -q '"packageName":"mts"' "$checked/release-signature.json" || fail_as "$unsigned"
grep -q "\"packageVersion\":\"$version\"" "$checked/release-signature.json" || fail_as "$unsigned"
manifest_digest=$(shasum -a 256 "$checked/release-manifest.json" | sed 's/[[:space:]].*$//')
signed_manifest=$(sed -n 's/.*"manifestFileDigest":"sha256:\([^"]*\)".*/\1/p' "$checked/release-signature.json" | head -n 1)
[ "$manifest_digest" = "$signed_manifest" ] || fail_as "$unsigned"

mkdir -p "$tmp/unpacked"
tar -xzf "$archive" -C "$tmp/unpacked" 2>/dev/null || fail_as "$unsigned"
release="$tmp/unpacked/package/release"

machine=$(uname -m)
case "$machine" in arm64) arch=arm64 ;; x86_64) arch=x64 ;; *) fail_as "$generic" ;; esac
manifest="$release/release-manifest.json"
runtime_tail=$(sed -n 's/.*"componentId":"mts-bun-runtime"\(.*\)/\1/p' "$manifest" | sed 's/"componentId".*//' | head -n 1)
runtime_entry=$(printf '%s\n' "$runtime_tail" | sed -n "s|.*\({[^{}]*\"path\":\"mts-install/sealed-parts/bun/darwin-$arch/bun\"[^{}]*}\).*|\1|p" | head -n 1)
bun_digest=$(printf '%s\n' "$runtime_entry" | sed -n 's/.*"fileDigest":"\(sha256:[^"]*\)".*/\1/p')
bun="$release/components/mts-bun-runtime/mts-install/sealed-parts/bun/darwin-$arch/bun"
[ -f "$bun" ] && [ "sha256:$(shasum -a 256 "$bun" | sed 's/[[:space:]].*$//')" = "$bun_digest" ] || fail_as "$unsigned"
chmod 700 "$bun" || fail_as "$generic"

engine_tail=$(sed -n 's/.*"componentId":"mts-engine"\(.*\)/\1/p' "$manifest" | sed 's/"componentId".*//' | head -n 1)
installer_entry=$(printf '%s\n' "$engine_tail" | sed -n 's|.*\({[^{}]*"path":"mts-install/runtime/install-release.ts"[^{}]*}\).*|\1|p' | head -n 1)
installer_digest=$(printf '%s\n' "$installer_entry" | sed -n 's/.*"fileDigest":"\(sha256:[^"]*\)".*/\1/p')
installer="$release/components/mts-engine/mts-install/runtime/install-release.ts"
[ -f "$installer" ] && [ "sha256:$(shasum -a 256 "$installer" | sed 's/[[:space:]].*$//')" = "$installer_digest" ] || fail_as "$unsigned"

product_entry=$(printf '%s\n' "$engine_tail" | sed -n 's|.*\({[^{}]*"path":"mts-install/product.ts"[^{}]*}\).*|\1|p' | head -n 1)
product_digest=$(printf '%s\n' "$product_entry" | sed -n 's/.*"fileDigest":"\(sha256:[^"]*\)".*/\1/p')
product="$release/components/mts-engine/mts-install/product.ts"
[ -f "$product" ] && [ "sha256:$(shasum -a 256 "$product" | sed 's/[[:space:]].*$//')" = "$product_digest" ] || fail_as "$unsigned"

lock_entry=$(printf '%s\n' "$engine_tail" | sed -n 's|.*\({[^{}]*"path":"MY-MIND/MY-SYSTEM/utilities/mts-file-lock.ts"[^{}]*}\).*|\1|p' | head -n 1)
lock_digest=$(printf '%s\n' "$lock_entry" | sed -n 's/.*"fileDigest":"\(sha256:[^"]*\)".*/\1/p')
lock_module="$release/components/mts-engine/MY-MIND/MY-SYSTEM/utilities/mts-file-lock.ts"
[ -f "$lock_module" ] && [ "sha256:$(shasum -a 256 "$lock_module" | sed 's/[[:space:]].*$//')" = "$lock_digest" ] || fail_as "$unsigned"

(cd "$release" && HOME="$home" "$bun" "$installer" "$release" "$content_root" "$state_root" --verify-only) >/dev/null 2>&1 || fail_as "$unsigned"
(cd "$release" && HOME="$home" "$bun" "$installer" "$release" "$content_root" "$state_root" --rollback-if-present) >/dev/null 2>&1 || fail_as "$generic"
save_code="$release/components/mts-engine/mts-install/runtime/save-access-code.ts"
save_error="$tmp/save-code-error"
step='saving the Mindy TimeSaver access code on this Mac'
if printf '%s\n' "$code" | (cd "$release" && HOME="$home" "$bun" "$save_code") >/dev/null 2>"$save_error"; then :
elif grep -q '^This Mac already has a different Mindy TimeSaver access code\.$' "$save_error"; then fail_as "$different"
else fail_as "$generic"
fi
install_result="$tmp/install.json"
step='installing Mindy TimeSaver'
had_previous=false
[ ! -f "$state_root/install-state.json" ] || had_previous=true
(cd "$release" && HOME="$home" "$bun" "$installer" "$release" "$content_root" "$state_root" --prepare) >"$install_result" 2>/dev/null || fail_as "$generic"

marketplace="$state_root/plugin-marketplace"
installed_marketplace_name='mindy-memory'
installed_plugin_reference='timesaver@mindy-memory'
registered=false
step='making Mindy TimeSaver available in your apps'
claude_present=false
codex_present=false
if command -v claude >/dev/null 2>&1; then claude_present=true; fi
app_codex=${CODEX_CLI_PATH:-}
if ! command -v codex >/dev/null 2>&1 && [ -x "$app_codex" ] && [ "${app_codex##*/}" = codex ]; then PATH="$PATH:${app_codex%/codex}"; export PATH; fi
if command -v codex >/dev/null 2>&1; then codex_present=true; fi

old_public_timesaver() {
 # An unreadable or unfamiliar source leaves this registration alone.
 "$1" plugin marketplace list --json >"$tmp/marketplaces-$1.json" 2>/dev/null || return 1
 (cd "$release" && "$bun" -e '
  const [app, path] = process.argv.slice(1);
  const listing = await Bun.file(path).json();
  const entries = app === "claude" ? listing : listing.marketplaces;
  const old = Array.isArray(entries) && entries.find(entry => entry.name === "timesaver");
  const repository = "The-Monday-Stack/mindy-timesaver";
  const gitSources = [repository, `https://github.com/${repository}`, `https://github.com/${repository}.git`, `git@github.com:${repository}.git`];
  const matches = app === "claude"
   ? old?.source === "github" && old.repo === repository
   : old?.marketplaceSource?.sourceType === "git" && gitSources.includes(old.marketplaceSource.source);
  process.exit(matches ? 0 : 1);
 ' "$1" "$tmp/marketplaces-$1.json") >/dev/null 2>&1
}

remove_old_registration() {
	# The old content and state folders remain untouched. Only app registrations go.
	if [ "$claude_present" = true ]; then
		if old_public_timesaver claude; then
			claude plugin uninstall timesaver@timesaver --scope user >/dev/null 2>&1 || :
			claude plugin marketplace remove timesaver --scope user >/dev/null 2>&1 || :
		fi
		claude plugin uninstall timesaver@timesaver-marketplace --scope user >/dev/null 2>&1 || :
		claude plugin marketplace remove timesaver-marketplace --scope user >/dev/null 2>&1 || :
		claude plugin uninstall timecone@timecone-marketplace --scope user >/dev/null 2>&1 || :
		claude plugin uninstall timecone@timecone --scope user >/dev/null 2>&1 || :
		claude plugin marketplace remove timecone-marketplace --scope user >/dev/null 2>&1 || :
		claude plugin marketplace remove timecone --scope user >/dev/null 2>&1 || :
	fi
	if [ "$codex_present" = true ]; then
		if old_public_timesaver codex; then
			codex plugin remove timesaver@timesaver --json >/dev/null 2>&1 || :
			codex plugin marketplace remove timesaver --json >/dev/null 2>&1 || :
		fi
		codex plugin remove timesaver@timesaver-marketplace --json >/dev/null 2>&1 || :
		codex plugin marketplace remove timesaver-marketplace --json >/dev/null 2>&1 || :
		codex plugin remove timecone@timecone-marketplace --json >/dev/null 2>&1 || :
		codex plugin remove timecone@timecone --json >/dev/null 2>&1 || :
		codex plugin marketplace remove timecone-marketplace --json >/dev/null 2>&1 || :
		codex plugin marketplace remove timecone --json >/dev/null 2>&1 || :
	fi
}

rollback_registration() {
	if [ "$claude_present" = true ]; then
		claude plugin uninstall "$installed_plugin_reference" --scope user >/dev/null 2>&1 || :
		claude plugin marketplace remove "$installed_marketplace_name" --scope user >/dev/null 2>&1 || :
	fi
	if [ "$codex_present" = true ]; then
		codex plugin remove "$installed_plugin_reference" --json >/dev/null 2>&1 || :
		codex plugin marketplace remove "$installed_marketplace_name" --json >/dev/null 2>&1 || :
	fi
	(cd "$release" && HOME="$home" "$bun" "$installer" "$release" "$content_root" "$state_root" --rollback) >/dev/null 2>&1 || return 1
	if [ "$had_previous" = true ]; then
		restored_marketplace_name=$(cd "$release" && "$bun" -e 'const value = await Bun.file(process.argv[1]).json(); if (typeof value.name !== "string" || !/^[a-zA-Z0-9_-]+$/.test(value.name)) process.exit(1); process.stdout.write(value.name);' "$marketplace/.claude-plugin/marketplace.json") || return 1
		restored_plugin_reference="timesaver@$restored_marketplace_name"
		if [ "$claude_present" = true ]; then (cd "$content_root" && claude plugin marketplace add "$marketplace" --scope user >/dev/null 2>&1 && claude plugin install "$restored_plugin_reference" --scope user >/dev/null 2>&1) || return 1; fi
		if [ "$codex_present" = true ]; then (cd "$content_root" && codex plugin marketplace add "$marketplace" --json >/dev/null 2>&1 && codex plugin add "$restored_plugin_reference" --json >/dev/null 2>&1) || return 1; fi
	fi
}

remove_old_registration

if command -v claude >/dev/null 2>&1; then
	if ! (cd "$content_root" && claude plugin marketplace add "$marketplace" --scope user >/dev/null 2>&1 && claude plugin install "$installed_plugin_reference" --scope user >/dev/null 2>&1); then rollback_registration; fail_as "$generic"; fi
	registered=true
fi
if command -v codex >/dev/null 2>&1; then
	if ! (cd "$content_root" && codex plugin marketplace add "$marketplace" --json >/dev/null 2>&1 && codex plugin add "$installed_plugin_reference" --json >/dev/null 2>&1); then rollback_registration; fail_as "$generic"; fi
	registered=true
fi
if [ "$registered" != true ]; then rollback_registration; fail_as "$generic"; fi
(cd "$release" && HOME="$home" "$bun" "$installer" "$release" "$content_root" "$state_root" --finalize) >/dev/null 2>&1 || { rollback_registration; fail_as "$generic"; }

finished=true
printf '%s\n' "Mindy TimeSaver is now in $content_root"
print_how_it_works
