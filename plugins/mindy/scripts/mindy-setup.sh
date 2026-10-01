#!/bin/sh
set -eu

code=
if [ "${1:-}" = "--code" ] && [ "${2:-}" != "" ]; then code=$2; fi
if [ -z "$code" ]; then printf '%s\n' 'This needs your MINDY access code.'; exit 0; fi
exec 2>/dev/null

# The code is a secret. Everything this script prints or keeps goes through redact, which replaces
# the whole code, and its signature half on its own, with [code removed]. A string shorter than a
# real code's parts is left alone, so a mistyped scrap cannot garble the sentences.
code_signature=${code##*.}
[ "$code_signature" != "$code" ] || code_signature=
redact() {
	MINDY_SETUP_REDACT_CODE=$code MINDY_SETUP_REDACT_SIGNATURE=$code_signature awk '
		BEGIN { secrets[1] = ENVIRON["MINDY_SETUP_REDACT_CODE"]; secrets[2] = ENVIRON["MINDY_SETUP_REDACT_SIGNATURE"]; minimum[1] = 8; minimum[2] = 16 }
		{
			line = $0
			for (k = 1; k <= 2; k++) {
				secret = secrets[k]; size = length(secret)
				if (size < minimum[k]) continue
				out = ""
				while ((at = index(line, secret)) > 0) { out = out substr(line, 1, at - 1) "[code removed]"; line = substr(line, at + size) }
				line = out line
			}
			print line
		}'
}
say() { printf '%s\n' "$1" | redact; }
# The first line of a reason worth reading: not blank, not a numbered source excerpt, not a caret,
# not a banner of repeated = - * # ~ or _. A Bun crash report opens with a banner and a block about
# the machine, so its panic line, when there is one, is the reason.
first_meaningful() {
	redact | awk '
		{ gsub(/[[:cntrl:]]/, " ") }
		/^[[:space:]]*$/ { next }
		/^[[:space:]]*[0-9]+[[:space:]]*\|/ { next }
		/^[[:space:]]*\^[[:space:]]*$/ { next }
		/^[[:space:]]*[=*#~_-][=*#~_-][=*#~_-]+[[:space:]]*$/ { next }
		{ line = $0; sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line); if (length(line) > 300) line = substr(line, 1, 297) "..." }
		line ~ /^panic[(:]/ { print line; found = 1; exit }
		first == "" { first = line }
		END { if (!found && first != "") print first }'
}
reason_of() {
	for reason_file in "$@"; do
		if [ -f "$reason_file" ]; then
			reason_line=$(first_meaningful <"$reason_file")
			if [ -n "$reason_line" ]; then printf '%s\n' "$reason_line"; return 0; fi
		fi
	done
	return 0
}

plugin_root="$(dirname "$0")/.."
tmp=
home=
version_dir=
created_version_dir=false
archive=
finished=false
said=false
kept=false
signal=
step='starting setup'
stop_message=
stop_reason=
stop_status=
stop_line=
sent_details=
version=
active_version=
harness_list=
harnesses_checked=false
# The decided wording (Event 1851080). Each is printed alone; the stop note keeps the reason. Every
# other stop prints one line, "Setup stopped while <step>: <reason>".
not_issued_message='This is not a MINDY access code. Check the code you were given.'
different_code_message='This Mac already has a different MINDY access code.'
unsigned_message='This download is not a signed MINDY release.'
unreachable_message="Setup could not reach MINDY's download server, so MINDY could not be sent the details. Check you are online, then type /mindy with your access code again."
# The script's own sentences for two of the download server's answers. Provisional: not yet decided.
not_active_message='This MINDY access code is no longer active.'
too_many_message='Too many tries from this internet connection in the last minute. Wait a minute, then type /mindy with your access code again.'
# What a stop line shows in place of a reason it must not show. Not yet decided.
reason_kept="the reason is kept in setup's stop note on this Mac, in ~/.mindy/setup-stops"
reason_not_shown='the reason is not shown here'
# The gate's own sentences (build-machine-stack src/mindy-gate-rules.js), matched exactly and never
# shown. The engine's own not-issued sentence is the same words, and the engine passes the gate's two
# code sentences on when the gate refuses its own request.
gate_not_issued_sentence='This code is not one Mike issued. Check the code in Mike'"'"'s message, or ask Mike.'
gate_not_active_sentence='This code is no longer active. Ask Mike.'
gate_too_many_sentence='Too many requests. Wait a minute and try again.'

# Each step names itself before it starts, and its own error output goes to step.err, so an
# unexpected exit under set -eu can say which step stopped and what the failed command said.
begin() {
	step=$1
	if [ -n "$tmp" ]; then exec 2>"$tmp/step.err"; fi
}

# Sending a stop's details to MINDY is not built yet: MINDY's download server cannot receive them
# until that is built separately. Until then this returns 1, and a stop prints "Setup stopped while
# <step>: <reason>", keeps the stop note, and never claims anything was sent. Switching to the approved
# sentence is this one function: send the kept note at $stop_file, set sent_details to what was sent,
# and return 0. tell then prints the approved sentence, then sent_details.
send_stop_report() {
	return 1
}

# One check for every word a stop shows that someone else wrote: a tool's output, the engine's
# answer, a page that answered in place of the download server, or why the stop note could not be
# kept. The name the gate's sentences use must never reach the screen, in any letter case. The check
# reads the text as it would be shown, with the code already removed, and with the member's own home
# folder path taken out, compared as plain text: that folder name is the member's own and names no
# one else. What is shown is unchanged.
# must_not_show <text>
must_not_show() {
	printf '%s\n' "$1" | redact | MINDY_SETUP_HOME=$home awk '
		BEGIN { home = ENVIRON["MINDY_SETUP_HOME"] }
		{
			line = $0
			if (home != "") { out = ""; while ((at = index(line, home)) > 0) { out = out substr(line, 1, at - 1) " "; line = substr(line, at + length(home)) } line = out line }
			if (tolower(line) ~ /mike/) found = 1
		}
		END { exit (found ? 0 : 1) }'
}

# The stop note is kept first, so the step line can say when it could not be kept, and why. With no
# HOME the reason already says so. A decided message is printed word for word, and when its note
# could not be kept, the next line says so. A reason that must not be shown is replaced by where it
# is kept, or, when the note could not be kept, by saying it is not shown; the note keeps it in full.
# tell <setup exit status>
tell() {
	[ -n "$stop_reason" ] || stop_reason="the command for $step gave no reason${stop_status:+ (exit status $stop_status)}"
	reason_withheld=false
	shown_reason=$stop_reason
	if must_not_show "$stop_reason"; then reason_withheld=true; shown_reason=$reason_kept; fi
	if [ -n "$stop_message" ]; then stop_line=$stop_message; else stop_line="Setup stopped while $step: $shown_reason"; fi
	if keep_stop "$1"; then note_kept=true; else note_kept=false; fi
	lost_note=
	if [ "$note_kept" = false ] && [ -n "$home" ]; then
		if must_not_show "$keep_failure"; then lost_note='(the stop note could not be kept)'; else lost_note="(the stop note could not be kept: $keep_failure)"; fi
	fi
	if [ -n "$stop_message" ]; then
		say "$stop_message" || :
		[ -z "$lost_note" ] || say "$lost_note" || :
		return 0
	fi
	if [ "$note_kept" = true ] && send_stop_report; then
		say "Setup stopped while $step. MINDY has been sent the details:" || :
		say "$sent_details" || :
		return 0
	fi
	if [ "$note_kept" = false ] && [ "$reason_withheld" = true ]; then stop_line="Setup stopped while $step: $reason_not_shown"; fi
	[ -z "$lost_note" ] || stop_line="$stop_line $lost_note"
	say "$stop_line" || :
}

# The download server's own sentence from an error answer, when it gave one.
server_error() {
	sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -n 1
}

# An answer other than 200. The script never prints the download server's own words as a sentence of
# its own. Three of the gate's answers are matched exactly, each to the script's own sentence (the
# gate's rules are build-machine-stack src/mindy-gate-rules.js; it refuses with 403 and limits with
# 429): the code was not issued, the code is no longer active (its answer for a revoked or expired
# code too), and too many requests. Any other 401, 403 or 429, whether from the gate or from something
# in the way such as a proxy, stops with the status and the answer's own message as the reason, unless
# that message must not be shown, when the status alone is shown. The stop note keeps the whole answer.
# Any other status stops with the status as the reason.
# stop_for_status <status> <answer file>
stop_for_status() {
	message=$(server_error "$2")
	status_reason="the answer was status $1"
	case "$1" in
		401|403)
			if [ "$message" = "$gate_not_issued_sentence" ]; then stop_saying "$not_issued_message" "$status_reason: $message"; fi
			if [ "$message" = "$gate_not_active_sentence" ]; then stop_saying "$not_active_message" "$status_reason: $message"; fi ;;
		429)
			if [ "$message" = "$gate_too_many_sentence" ]; then stop_saying "$too_many_message" "$status_reason: $message"; fi ;;
	esac
	case "$1" in
		401|403|429)
			shown=$(printf '%s\n' "$message" | first_meaningful)
			if [ -n "$shown" ] && ! must_not_show "$shown"; then stop "$status_reason: $shown"; fi ;;
	esac
	stop "$status_reason"
}

# The enrol and install steps ask the gate for themselves, and pass the gate's two code sentences on
# inside their own answer. Either one stops with setup's own sentence for it, as on the direct route.
# stop_for_gate_sentence <step output> <exit status of the step's command>
stop_for_gate_sentence() {
	if grep -qF "$gate_not_issued_sentence" "$1"; then stop_saying "$not_issued_message" "$(reason_of "$1")" "$2"; fi
	if grep -qF "$gate_not_active_sentence" "$1"; then stop_saying "$not_active_message" "$(reason_of "$1")" "$2"; fi
}

# curl could not reach the download server at all: 5 no proxy, 6 no host, 7 no connection, 28 timed
# out, 35 no TLS connection. Any other curl failure, such as 23 (could not write) or 56 (cut off
# mid-transfer), is an ordinary stop with curl's own line as the reason.
# stop_for_curl <exit status> <error file>
stop_for_curl() {
	case "$1" in 5|6|7|28|35) stop_saying "$unreachable_message" "$(reason_of "$2")" "$1" ;; esac
	stop "$(reason_of "$2")" "$1"
}

plugin_version() {
	plugin_version_value=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$plugin_root/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)
	printf '%s\n' "${plugin_version_value:-unknown}"
}

# Every failed run keeps its evidence at ~/.mindy/setup-stops/<UTC time>.txt, readable only by the
# member, so the whole reason can be read afterwards. $tmp is still removed. When the note cannot be
# kept, keep_stop returns 1 and leaves the first line of why in keep_failure.
# keep_stop <setup exit status>
keep_stop() {
	[ "$kept" = false ] || return 0
	kept=true
	keep_failure=
	if [ -z "$home" ]; then keep_failure='HOME is not set'; return 1; fi
	stops="$home/.mindy/setup-stops"
	if keep_error=$( (umask 077 && mkdir -p "$stops") 2>&1 ); then :; else
		keep_failure=$(printf '%s\n' "$keep_error" | first_meaningful)
		[ -n "$keep_failure" ] || keep_failure="$stops could not be made"
		return 1
	fi
	stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ) || stamp=unknown-time
	file_stamp=$(printf '%s\n' "$stamp" | tr ':' '-')
	stop_file="$stops/$file_stamp.txt"
	[ ! -e "$stop_file" ] || stop_file="$stops/$file_stamp-$$.txt"
	if [ -n "$stop_status" ]; then step_status_text=$stop_status
	elif [ -n "$signal" ]; then step_status_text="none, a $signal signal stopped it"
	else step_status_text='none, a check stopped it'; fi
	if keep_error=$( (
		umask 077
		{
			printf '%s\n' 'MINDY setup stop'
			printf 'Time (UTC): %s\n' "$stamp"
			printf 'Step: %s\n' "$step"
			printf 'Reason: %s\n' "$stop_reason"
			printf 'Said to the member: %s\n' "$stop_line"
			printf 'Step exit status: %s\n' "$step_status_text"
			printf 'Setup exit status: %s\n' "$1"
			printf 'MINDY version on the download server: %s\n' "${version:-not known yet}"
			printf 'MINDY version already installed: %s\n' "${active_version:-none}"
			if [ "$harnesses_checked" = true ]; then printf 'Harnesses for this setup: %s\n' "${harness_list:-none found}"; else printf 'Harnesses for this setup: not checked yet\n'; fi
			printf 'Plugin version: %s\n' "$(plugin_version)"
			printf 'Machine (uname -m): %s\n' "$(uname -m 2>/dev/null || printf 'unknown')"
			printf 'macOS: %s\n' "$(sw_vers -productVersion 2>/dev/null || printf 'unknown')"
			if [ -n "$tmp" ]; then
				for evidence in "$tmp"/*.out "$tmp"/*.err "$tmp"/packument.json; do
					[ -s "$evidence" ] || continue
					printf '\n--- %s ---\n' "${evidence##*/}"
					redact <"$evidence" | head -c 65536
					printf '\n'
				done
			fi
		} | redact >"$stop_file"
	) 2>&1 ) && [ -s "$stop_file" ]; then return 0; fi
	keep_failure=$(printf '%s\n' "$keep_error" | first_meaningful)
	[ -n "$keep_failure" ] || keep_failure="$stop_file could not be written"
	rm -f "$stop_file" 2>/dev/null || :
	return 1
}

cleanup() {
	exit_status=$?
	set +e
	trap '' HUP INT TERM
	if [ "$finished" = false ]; then
		if [ "$said" = false ]; then
			said=true
			stop_message=
			if [ -n "$signal" ]; then
				stop_status=
				stop_reason="it was stopped by a $signal signal"
			else
				stop_status=$exit_status
				stop_reason=$(reason_of "$tmp/step.err")
				[ -n "$stop_reason" ] || stop_reason="a command stopped with exit status $exit_status"
			fi
			tell "$exit_status"
		fi
		keep_stop "$exit_status" || :
		if [ -n "$archive" ] && [ -f "$archive" ]; then rm -f "$archive"; fi
		if [ "$created_version_dir" = true ] && [ -n "$version_dir" ]; then rm -rf "$version_dir"; fi
	fi
	if [ -n "$tmp" ]; then rm -rf "$tmp"; fi
}
trap cleanup EXIT
trap 'signal=HUP; exit 1' HUP
trap 'signal=INT; exit 1' INT
trap 'signal=TERM; exit 1' TERM
# stop <reason> [exit status of the step's command]
stop() {
	said=true
	stop_reason=$1
	stop_status=${2:-}
	tell 1
	exit 1
}
# stop_saying <message printed alone> <reason for the stop note> [exit status of the step's command]
stop_saying() {
	stop_message=$1
	shift
	stop "$@"
}

begin 'finding your home folder'
if [ -z "${HOME:-}" ]; then
	stop 'HOME is not set'
else
	home=$HOME
fi
client_root="$home/mindy"
downloads="$home/.mindy/downloads"

begin 'making a temporary folder'
if made=$(mktemp -d 2>&1) && [ -d "$made" ]; then tmp=$made; else stop "$(printf '%s\n' "$made" | first_meaningful)"; fi

begin "asking MINDY's download server for the latest release"
packument="$tmp/packument.json"
if status=$(curl -sS -H "Authorization: Bearer $code" -H 'Accept: application/json' -o "$packument" -w '%{http_code}' 'https://gate.mindy.build/mindy' 2>"$tmp/curl-packument.err"); then :; else
	stop_for_curl "$?" "$tmp/curl-packument.err"
fi
[ "$status" = 200 ] || stop_for_status "$status" "$packument"
# A 200 answer that is not MINDY's release list at all, such as a Wi-Fi sign-in page, says so.
if ! grep -q '"dist-tags"[[:space:]]*:' "$packument" 2>/dev/null; then
	answer_start=$(reason_of "$packument")
	if [ -n "$answer_start" ]; then stop "the answer is not MINDY's release list; it begins: $answer_start"; fi
	stop 'the answer was empty'
fi

tags=$(sed -n 's/.*"dist-tags"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p' "$packument" | head -n 1)
version=$(printf '%s\n' "$tags" | sed -n 's/.*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$version" ] || stop "the download server's answer names no latest release"
version_entry=$(sed -n "s/.*\"$version\"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p" "$packument" | head -n 1)
integrity=$(printf '%s\n' "$version_entry" | sed -n 's/.*"integrity"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
case "$integrity" in sha512-*) ;; *) stop "the download server's answer for MINDY $version has no sha512 integrity value" ;; esac

begin 'checking which MINDY is already here'
active="$client_root/.mindy/release-selection/active-release.json"
if [ -f "$active" ]; then active_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$active" | head -n 1); fi
if [ "$active_version" = "$version" ]; then finished=true; printf '%s\n' 'MINDY is already installed.'; exit 0; fi
action=install
if [ -n "$active_version" ]; then action=update; fi

# Enrol only the harnesses whose command is on this Mac: the install runs `claude --version` or
# `codex --version` for each one it registers, so a harness without its command stops the install.
# An update keeps the harnesses recorded when MINDY was installed, because the enrol step refuses
# to change them once a release is active.
begin 'checking for Claude Code and Codex'
if [ "$action" = update ]; then
	recorded=$(sed -n 's/.*"harnessIds"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' "$client_root/.mindy/update-verifier.json" 2>/dev/null | head -n 1)
	case "$recorded" in *'"claude-code"'*) harness_list='claude-code' ;; esac
	case "$recorded" in *'"codex"'*) harness_list="${harness_list:+$harness_list }codex" ;; esac
fi
if [ -z "$harness_list" ]; then
	if command -v claude >/dev/null 2>&1; then harness_list='claude-code'; fi
	if command -v codex >/dev/null 2>&1; then harness_list="${harness_list:+$harness_list }codex"; fi
fi
harnesses_checked=true
[ -n "$harness_list" ] || stop "neither claude nor codex is on this Mac's PATH"
set --
for harness in $harness_list; do set -- "$@" --harness "$harness"; done

begin 'downloading MINDY'
mkdir -p "$downloads"
version_dir="$downloads/$version"
if [ ! -d "$version_dir" ]; then mkdir -p "$version_dir"; created_version_dir=true; fi
archive="$version_dir/mindy.tgz"
if status=$(curl -sS -H "Authorization: Bearer $code" -o "$archive" -w '%{http_code}' "https://gate.mindy.build/mindy/-/mindy-$version.tgz" 2>"$tmp/curl-archive.err"); then :; else
	stop_for_curl "$?" "$tmp/curl-archive.err"
fi
if [ "$status" != 200 ]; then
	head -c 4096 "$archive" >"$tmp/download-answer.out" 2>/dev/null || :
	stop_for_status "$status" "$tmp/download-answer.out"
fi

begin 'checking the download'
actual=$(shasum -a 512 "$archive" 2>"$tmp/shasum-archive.err" | sed 's/[[:space:]].*$//')
expected=$(printf '%s\n' "${integrity#sha512-}" | openssl base64 -d -A 2>"$tmp/openssl-base64.err" | od -An -tx1 2>"$tmp/od.err" | tr -d ' \n')
if [ -z "$expected" ]; then
	decode_reason=$(reason_of "$tmp/openssl-base64.err" "$tmp/od.err")
	[ -n "$decode_reason" ] || decode_reason="the download server's sha512 integrity value could not be decoded"
	stop "$decode_reason"
fi
# An empty digest means shasum itself failed on this Mac, which says nothing about the download.
[ -n "$actual" ] || stop "$(reason_of "$tmp/shasum-archive.err")"
[ "$actual" = "$expected" ] || stop "the download's sha512 digest does not match the download server's integrity value"

begin 'unpacking the download'
mkdir -p "$tmp/unpacked"
if tar -xzf "$archive" -C "$tmp/unpacked" 2>"$tmp/tar.err"; then :; else tar_status=$?; stop "$(reason_of "$tmp/tar.err")" "$tar_status"; fi

begin 'checking the download is a signed MINDY release'
release="$tmp/unpacked/package/release"
key="$plugin_root/keys/mindy-release-signature.pem"
[ -f "$release/release-signature.sig" ] && [ -f "$release/release-signature.json" ] || stop_saying "$unsigned_message" 'the download has no release signature'
if openssl dgst -sha256 -verify "$key" -signature "$release/release-signature.sig" "$release/release-signature.json" >"$tmp/openssl-verify.out" 2>"$tmp/openssl-verify.err"; then :; else
	verify_status=$?
	# Only openssl's own verdict means the signature does not verify: LibreSSL, macOS's openssl, says
	# "Error Verifying Data" and OpenSSL 3 says "Verification failure". Anything else is openssl
	# failing to run the check on this Mac.
	if grep -qi -e 'verification failure' -e 'error verifying data' "$tmp/openssl-verify.out" "$tmp/openssl-verify.err" 2>/dev/null; then
		stop_saying "$unsigned_message" "$(reason_of "$tmp/openssl-verify.err" "$tmp/openssl-verify.out")" "$verify_status"
	fi
	stop "$(reason_of "$tmp/openssl-verify.err" "$tmp/openssl-verify.out")" "$verify_status"
fi
manifest_file_digest=$(shasum -a 256 "$release/release-manifest.json" 2>"$tmp/shasum-manifest.err" | sed 's/[[:space:]].*$//')
[ -n "$manifest_file_digest" ] || stop "$(reason_of "$tmp/shasum-manifest.err")"
signed_manifest_file_digest=$(sed -n 's/.*"manifestFileDigest"[[:space:]]*:[[:space:]]*"sha256:\([^"]*\)".*/\1/p' "$release/release-signature.json" | head -n 1)
[ -n "$signed_manifest_file_digest" ] && [ "$manifest_file_digest" = "$signed_manifest_file_digest" ] || stop_saying "$unsigned_message" 'the release manifest does not match its signature'

begin "checking this Mac's chip"
machine=$(uname -m 2>"$tmp/uname.err")
case "$machine" in arm64) arch=arm64;; x86_64) arch=x64;; *) stop "this Mac reports its chip as ${machine:-nothing}";; esac

begin 'checking the download is a signed MINDY release'
bun="$release/components/mindy-bun-runtime/darwin-$arch/bun"
runtime_component=$(sed -n 's/.*"componentId"[[:space:]]*:[[:space:]]*"mindy-bun-runtime"\(.*\)/\1/p' "$release/release-manifest.json" | sed 's/"componentId".*//')
runtime_entry=$(printf '%s\n' "$runtime_component" | sed -n "s|.*\({[^{}]*\"path\"[[:space:]]*:[[:space:]]*\"darwin-$arch/bun\"[^{}]*}\).*|\1|p" | head -n 1)
manifest_bun_digest=$(printf '%s\n' "$runtime_entry" | sed -n 's/.*"fileDigest"[[:space:]]*:[[:space:]]*"\(sha256:[^"]*\)".*/\1/p' | head -n 1)
[ -f "$bun" ] || stop_saying "$unsigned_message" "the download has no MINDY runtime for darwin-$arch"
actual_bun_digest="sha256:$(shasum -a 256 "$bun" 2>"$tmp/shasum-bun.err" | sed 's/[[:space:]].*$//')"
[ "$actual_bun_digest" != 'sha256:' ] || stop "$(reason_of "$tmp/shasum-bun.err")"
[ "$actual_bun_digest" = "$manifest_bun_digest" ] || stop_saying "$unsigned_message" 'the MINDY runtime in the download does not match the signed manifest'

begin 'getting the MINDY runtime ready'
if chmod 700 "$bun" 2>"$tmp/chmod.err"; then :; else chmod_status=$?; stop "$(reason_of "$tmp/chmod.err")" "$chmod_status"; fi

engine="$release/components/mindy-engine/mindy-install"
begin 'saving your access code on this Mac'
enrol="$tmp/enrol.out"
if "$bun" "$engine/delivery-credential-cli.ts" bootstrap-with-code --membership-code "$code" --client-root "$client_root" "$@" >"$enrol" 2>&1; then :; else
	enrol_status=$?
	message=$(sed -n '1p' "$enrol")
	# The engine's own sentences, matched exactly. Release 1.0.6 has the older different-code sentence.
	stop_for_gate_sentence "$enrol" "$enrol_status"
	if [ "$message" = "$different_code_message" ] || [ "$message" = 'This machine already has a different code. Ask Mike.' ]; then stop_saying "$different_code_message" "$message" "$enrol_status"; fi
	stop "$(reason_of "$enrol")" "$enrol_status"
fi

begin 'installing MINDY'
install="$tmp/install.out"
if "$bun" "$engine/delivery-cli.ts" --release-signature "$release/release-signature.json" --release-package "$archive" --operation-id "mindy-setup-$(date +%s)-$$" --action "$action" --client-root "$client_root" >"$install" 2>&1; then :; else
	install_status=$?
	stop_for_gate_sentence "$install" "$install_status"
	stop "$(reason_of "$install")" "$install_status"
fi

finished=true
printf '%s\n' "MINDY is now in $client_root"
