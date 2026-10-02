#!/bin/sh
set -eu

# How a member starts MINDY, in every message below that says so. This is the Claude Code form. It is
# written here and nowhere else in this script, so a different form is one edit. The /mindy skill
# repeats the no-code message, and a test holds the two the same.
start_mindy='type /mindy'
start_mindy_capital="$(printf '%s' "$start_mindy" | cut -c 1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$start_mindy" | cut -c 2-)"

# The decided wording (2 October 2026). The member sees exactly one of these when setup stops, and no
# other words. "MINDY has already been sent the details" is printed only when MINDY's download server
# took the stop report; otherwise the unreachable message or the not-taken ending is printed instead.
no_code_message="This needs your MINDY access code, which came in the message with your install steps. $start_mindy_capital, a space and your code, all on one line."
not_issued_message="This is not a MINDY access code, so setup can't use it. Copy the code again in full from the message it came in, then $start_mindy with it."
not_active_message="This MINDY access code is no longer active, so it can't download MINDY. MINDY has already been sent the details."
different_code_message="This Mac already has a different MINDY access code saved, and MINDY uses one code per Mac. $start_mindy_capital with that earlier code. MINDY has already been sent the details, in case you no longer have it."
unsigned_message="This download is not a signed MINDY release, so setup stopped before installing anything, to keep your Mac safe. MINDY has already been sent the details. Check you're on your usual internet connection, then $start_mindy with your access code again."
too_many_message="Too many tries from this internet connection in the last minute, so MINDY's download server is pausing for a moment. Wait a minute, then $start_mindy with your access code again."
unreachable_message="Setup could not reach MINDY's download server, so MINDY could not be sent the details. Check you are online, then $start_mindy with your access code again."
# Any other stop is "Setup stopped while <step>: <reason>." and one of these two endings.
details_sent_ending="MINDY has already been sent the details. $start_mindy_capital with your access code to try again."
details_not_taken_ending="MINDY's download server couldn't take the details just now. $start_mindy_capital with your access code to try again."
interrupted_message="Setup stopped because it was interrupted. $start_mindy_capital with your access code to start again."

# The code comes on standard input, first line, after --code-on-stdin, so it is not in this script's
# arguments for the process list to show. --code <code> still works, for a skill written before that.
code=
if [ "${1:-}" = "--code-on-stdin" ]; then code=$(sed -n '1p' | tr -d ' \t\r') || code=
elif [ "${1:-}" = "--code" ] && [ "${2:-}" != "" ]; then code=$2; fi
if [ -z "$code" ]; then printf '%s\n' "$no_code_message"; exit 0; fi
exec 2>/dev/null

# The code is a secret. Everything this script prints or keeps goes through redact, which replaces
# the whole code, and its signature half on its own, with [code removed]. Either one shorter than 16
# characters is left alone: a real code is far longer, and its signature half alone is 86 characters,
# so a mistyped scrap, or an ordinary word typed as the code, cannot garble the sentences.
code_signature=${code##*.}
[ "$code_signature" != "$code" ] || code_signature=
redact() {
	MINDY_SETUP_REDACT_CODE=$code MINDY_SETUP_REDACT_SIGNATURE=$code_signature awk '
		BEGIN { secrets[1] = ENVIRON["MINDY_SETUP_REDACT_CODE"]; secrets[2] = ENVIRON["MINDY_SETUP_REDACT_SIGNATURE"]; minimum[1] = 16; minimum[2] = 16 }
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
# curl to MINDY's download server, with the code's Authorization header read from a here-document on
# descriptor 3 rather than given as an argument, so the process list never shows the code.
# gate_curl <curl arguments>
gate_curl() {
	curl -H @/dev/fd/3 "$@" 3<<GATE_AUTHORIZATION
Authorization: Bearer $code
GATE_AUTHORIZATION
}
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
told=false
kept=false
signal=
step='starting setup'
stop_message=
stop_reason=
member_reason=
stop_status=
stop_file=
stop_stamp=
report_id=
keep_failure=
send_outcome=
member_names=
version=
active_version=
harness_list=
harnesses_checked=false
# What a stop shows in place of a reason it must not show. Not yet decided.
reason_kept="the reason is kept in setup's stop note on this Mac, in ~/.mindy/setup-stops"
reason_not_shown='the reason is not shown here'
# The gate's own sentences (build-machine-stack src/mindy-gate-rules.js), matched exactly and never
# relayed: the earlier words, and the words the gate uses since it took the decided wording. The
# engine's own not-issued sentence is the earlier words, and the engine passes the gate's two earlier
# code sentences on when the gate refuses its own request.
gate_not_issued_sentence='This code is not one Mike issued. Check the code in Mike'"'"'s message, or ask Mike.'
gate_not_active_sentence='This code is no longer active. Ask Mike.'
gate_too_many_sentence='Too many requests. Wait a minute and try again.'
gate_not_issued_sentence_now="This is not a MINDY access code, so setup can't use it. Copy the code again in full from the message it came in, then type /mindy with it."
gate_not_active_sentence_now="This MINDY access code is no longer active, so it can't download MINDY."
gate_too_many_sentence_now="Too many tries from this internet connection in the last minute, so MINDY's download server is pausing for a moment. Wait a minute, then type /mindy with your access code again."
# The engine's own sentences for a different code already on this Mac: release 1.0.7 and later, and
# release 1.0.6.
engine_different_code_sentence='This Mac already has a different MINDY access code.'
engine_different_code_sentence_before='This machine already has a different code. Ask Mike.'

# Whether the text is one of the gate's sentences, in its earlier or its current words.
# is_gate_not_issued <text>, is_gate_not_active <text>, is_gate_too_many <text>
is_gate_not_issued() { [ "$1" = "$gate_not_issued_sentence" ] || [ "$1" = "$gate_not_issued_sentence_now" ]; }
is_gate_not_active() { [ "$1" = "$gate_not_active_sentence" ] || [ "$1" = "$gate_not_active_sentence_now" ]; }
is_gate_too_many() { [ "$1" = "$gate_too_many_sentence" ] || [ "$1" = "$gate_too_many_sentence_now" ]; }

# A reason as the end of a sentence: with a full stop, unless it already ends with one.
as_sentence() {
	case "$1" in *.) printf '%s' "$1" ;; *) printf '%s.' "$1" ;; esac
}

# Each step names itself before it starts, and its own error output goes to step.err, so an
# unexpected exit under set -eu can say which step stopped and what the failed command said.
begin() {
	step=$1
	if [ -n "$tmp" ]; then exec 2>"$tmp/step.err"; fi
}

# The member's own home folder path, set aside as plain text in any letter case, as a Mac's folders
# ignore case, and only as a whole path part: where a slash, a space, a quote, punctuation that closes
# a path, or the end of the line follows it. A longer folder name that begins with it is left as it is.
# set_home_aside <what stands in its place>
set_home_aside() {
	MINDY_SETUP_HOME=$home MINDY_SETUP_HOME_AS=$1 LC_ALL=C awk '
		BEGIN { home = tolower(ENVIRON["MINDY_SETUP_HOME"]); as = ENVIRON["MINDY_SETUP_HOME_AS"]; sub(/\/+$/, "", home) }
		{
			line = $0
			if (home != "") {
				out = ""
				while ((at = index(tolower(line), home)) > 0) {
					after = substr(line, at + length(home), 1)
					if (after == "" || after == "\047" || after ~ /[]\/[:space:]":;,)>`}]/) { out = out substr(line, 1, at - 1) as; line = substr(line, at + length(home)) }
					else { out = out substr(line, 1, at); line = substr(line, at + 1) }
				}
				line = out line
			}
			print line
		}'
}

# One check for every word a stop shows that someone else wrote: a tool's output, the engine's
# answer, a page that answered in place of the download server, or why the stop note could not be
# kept. The name the gate's sentences use must never reach the screen, in any letter case. The check
# reads the text as it would be shown, with the code already removed, and with the member's own home
# folder path taken out, compared as plain text: that folder name is the member's own and names no
# one else. The home path is taken out only as a whole path part, so a longer folder name that begins
# with it is still checked. What is shown is unchanged.
# must_not_show <text>
must_not_show() {
	printf '%s\n' "$1" | redact | set_home_aside ' ' | awk '
		{
			line = $0
			if (tolower(line) ~ /mike/) found = 1
		}
		END { exit (found ? 0 : 1) }'
}

# The member's names on this Mac, each replaced with [name removed] wherever it stands as a whole
# word, in any letter case: their full name, each word of it of three letters or more, and their user
# name. The longest is removed first, so a user name that is also the first word of the full name
# never leaves the rest of the full name behind. A full name or user name shorter than two characters
# is left alone, as it could not be told from an ordinary letter.
without_names() {
	MINDY_SETUP_NAMES=$member_names LC_ALL=C awk '
		function add(name, k) {
			for (k = 1; k <= count; k++) if (names[k] == name) return
			names[++count] = name
		}
		BEGIN {
			split(ENVIRON["MINDY_SETUP_NAMES"], list, "\n")
			user = tolower(list[1]); full = tolower(list[2])
			if (length(full) >= 2) add(full)
			words = split(full, part, /[[:space:]]+/)
			for (i = 1; i <= words; i++) if (length(part[i]) >= 3) add(part[i])
			if (length(user) >= 2) add(user)
			for (i = 2; i <= count; i++) {
				name = names[i]
				for (j = i - 1; j >= 1 && length(names[j]) < length(name); j--) names[j + 1] = names[j]
				names[j + 1] = name
			}
		}
		{
			line = $0
			for (k = 1; k <= count; k++) {
				name = names[k]; size = length(name); out = ""
				while ((at = index(tolower(line), name)) > 0) {
					before = at > 1 ? substr(line, at - 1, 1) : substr(out, length(out), 1)
					after = substr(line, at + size, 1)
					if (before !~ /[A-Za-z0-9_]/ && after !~ /[A-Za-z0-9_]/) { out = out substr(line, 1, at - 1) "[name removed]"; line = substr(line, at + size) }
					else { out = out substr(line, 1, at); line = substr(line, at + 1) }
				}
				line = out line
			}
			print line
		}'
}

# Text that is about to leave this Mac: the code and its signature half removed, the member's home
# folder path replaced with ~, and their names removed.
for_sending() {
	redact | set_home_aside '~' | without_names
}

# Text read from standard input as the inside of a JSON string, at most <bytes> bytes before it is
# escaped: what must not leave this Mac taken out first, any broken UTF-8 at the cut dropped, control
# characters other than tab and newline dropped, then \ " tab and newline escaped. Each field's bytes
# are capped so that the whole report stays inside the download server's 131072 bytes even if every
# byte had to be escaped.
# json_text <bytes>
json_text() {
	for_sending | head -c "$1" | if command -v iconv >/dev/null 2>&1; then iconv -c -f UTF-8 -t UTF-8 2>/dev/null; else cat; fi \
		| LC_ALL=C tr -d '\000-\010\013-\037\177' \
		| LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$(printf '\t')/\\\\t/g" \
		| LC_ALL=C awk '{ printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }'
}

# One line of text as the inside of a JSON string, its line breaks made spaces.
# json_line <text> <bytes>
json_line() {
	printf '%s' "$1" | tr '\n' ' ' | json_text "$2"
}

# Which app is running setup: Claude Code marks the commands it runs with CLAUDECODE, and Codex with
# CODEX_THREAD_ID, or CODEX_SANDBOX when it runs them in its sandbox.
app_name() {
	if [ -n "${CLAUDECODE:-}" ]; then printf '%s\n' 'Claude Code'
	elif [ -n "${CODEX_THREAD_ID:-}${CODEX_SANDBOX:-}${CODEX_SANDBOX_NETWORK_DISABLED:-}" ]; then printf '%s\n' 'Codex'
	else printf '%s\n' 'not known'; fi
}

# The time a stop happened, once per stop, and the report id made from it: the stop note's file stamp
# and this run's process id, the same for every send of this stop and new for the next stop.
stop_time() {
	[ -z "$stop_stamp" ] || return 0
	stop_stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ) || stop_stamp=unknown-time
	report_id="$(printf '%s\n' "$stop_stamp" | tr ':' '-')-$$"
}

# Sends the stop's details to MINDY's download server, as build-machine-stack's
# src/mindy-setup-stop-rules.js reads them (report mindy-setup-stop/v1), with the whole code as the
# proof the sender holds it, exactly as the release list is asked for. Only the code's membership
# number, the part before the dot, is in the report itself. The member's home folder path, their
# names and the code never leave this Mac in the report: step, reason and stop note go through
# for_sending first. Call it only as a condition (if send_stop_report), so that set -e leaves its
# failures to it. It returns:
#   0 the server took the report: a 2xx answer whose body says "received": true, as the gate's
#     answer for a new stop (201) and for one it already had (200) both do (build-machine-stack
#     src/api/mindy-setup-stops.js)
#   1 something answered without taking it: any other status, or a 2xx without that body, such as a
#     filtering proxy or a Wi-Fi sign-in page answering in the server's place
#   2 the server was not reached: curl stopped, or there was no answer (status 000)
#   3 the code is not a MINDY access code: it has no membership number to send, or the route answered
#     403, which it gives only for a code it never issued, whatever the words of its refusal
# Whatever it returns, send_outcome says what came of it, for the note.
send_stop_report() {
	membership_number=${code%.*}
	case "$membership_number" in
		''|*[!A-Za-z0-9-]*) send_outcome='no, the access code has no membership number'; return 3 ;;
	esac
	if [ "$membership_number" = "$code" ] || [ "${#membership_number}" -lt 3 ] || [ "${#membership_number}" -gt 32 ]; then
		send_outcome='no, the access code has no membership number'
		return 3
	fi
	member_names=$(printf '%s\n%s\n' "$(id -un 2>/dev/null || :)" "$(id -F 2>/dev/null || :)")
	stop_time
	report_step=$(json_line "$step" 200)
	report_reason=$(json_line "$stop_reason" 2000)
	report_note=
	# The note, or, when it could not be kept, why not, as the member is not told.
	if [ "$note_kept" = true ] && [ -f "$stop_file" ]; then report_note=$(json_text 60000 <"$stop_file")
	elif [ -n "$keep_failure" ]; then report_note=$(json_line "The stop note could not be kept on this Mac: $keep_failure" 2000); fi
	report_app=$(app_name)
	report_mindy_version=$(json_line "$version" 64)
	report_macos_version=$(json_line "$(sw_vers -productVersion 2>/dev/null || :)" 64)
	send_answer=$(printf '{"report":"mindy-setup-stop/v1","reportId":"%s","membershipNumber":"%s","step":"%s","reason":"%s","stopNote":"%s","app":"%s","mindyVersion":"%s","macosVersion":"%s","stoppedAt":"%s"}' \
		"$report_id" "$membership_number" "$report_step" "$report_reason" "$report_note" "$report_app" "$report_mindy_version" "$report_macos_version" "$stop_stamp" \
		| gate_curl -sS --connect-timeout 5 --max-time 10 -H 'Content-Type: application/json' --data-binary @- -w '\n%{http_code}' 'https://gate.mindy.build/mindy/setup-stops' 2>/dev/null)
	send_exit=$?
	if [ "$send_exit" != 0 ]; then send_outcome="no, curl stopped with exit status $send_exit"; return 2; fi
	# The answer's body, then its status on the last line.
	send_status=$(printf '%s\n' "$send_answer" | tail -n 1)
	case "$send_status" in
		2[0-9][0-9])
			if printf '%s\n' "$send_answer" | sed '$d' | grep -q '"received"[[:space:]]*:[[:space:]]*true'; then
				send_outcome="yes, the answer was status $send_status"
				return 0
			fi
			send_outcome="no, the answer was status $send_status but did not say the stop was received"
			return 1 ;;
		000|'') send_outcome='no, there was no answer'; return 2 ;;
		403) send_outcome='no, the answer was status 403, as the code was not issued'; return 3 ;;
	esac
	send_outcome="no, the answer was status $send_status"
	return 1
}

# Tells the member, in one of the decided messages and nothing else, what stopped setup, chosen by
# what happened. The stop note is kept first, so the report can carry it; what came of sending, and
# what was said, are added to the note afterwards. Whether the note could be kept is in the note, or
# is the reason the note is missing; it is not told.
#
# - A signal stopped setup: the interrupted message. The member, or whatever ran setup, stopped it
#   and may be waiting for it to end, so nothing is sent.
# - The gate refused a code it never issued, the gate is pausing this connection, or the gate could not
#   be reached: that message alone. Nothing is sent.
# - Any other stop is sent to MINDY's download server, with its note when the note was kept. Then:
#   it was taken: the stop's own message, which says the details were sent (the code is no longer
#   active, this Mac already has a different code, or the download is not a signed release), or for
#   any other stop "Setup stopped while <step>: <reason>." and the sent ending;
#   it was not taken: "Setup stopped while <step>: <reason>." and the not-taken ending, where the
#   reason for the three messages above is that message's own first words;
#   the server was not reached: the unreachable message;
#   the code is not a MINDY access code: the not-issued message.
# A reason that must not be shown is replaced by where it is kept, or, when the note could not be
# kept, by saying it is not shown.
# tell <setup exit status>
tell() {
	[ -n "$stop_reason" ] || stop_reason="the command for $step gave no reason${stop_status:+ (exit status $stop_status)}"
	case "$stop_message" in
		"$not_active_message") member_reason='this MINDY access code is no longer active' ;;
		"$different_code_message") member_reason='this Mac already has a different MINDY access code saved' ;;
		"$unsigned_message") member_reason='this download is not a signed MINDY release' ;;
	esac
	shown_reason=${member_reason:-$stop_reason}
	reason_withheld=false
	if must_not_show "$shown_reason"; then reason_withheld=true; shown_reason=$reason_kept; fi
	stop_time
	if keep_stop "$1"; then note_kept=true; else note_kept=false; fi
	if [ "$note_kept" = false ] && [ "$reason_withheld" = true ]; then shown_reason=$reason_not_shown; fi
	send_outcome=
	if [ -n "$signal" ]; then
		send_outcome='no, a signal stopped setup'
		said_line=$interrupted_message
	elif [ "$stop_message" = "$not_issued_message" ] || [ "$stop_message" = "$too_many_message" ] || [ "$stop_message" = "$unreachable_message" ]; then
		said_line=$stop_message
	else
		if send_stop_report; then sent=0; else sent=$?; fi
		case "$sent" in
			0)
				if [ -n "$stop_message" ]; then said_line=$stop_message
				else said_line="Setup stopped while $step: $(as_sentence "$shown_reason") $details_sent_ending"; fi ;;
			2) said_line=$unreachable_message ;;
			3) said_line=$not_issued_message ;;
			*) said_line="Setup stopped while $step: $(as_sentence "$shown_reason") $details_not_taken_ending" ;;
		esac
	fi
	say "$said_line" || :
	told=true
	if [ "$note_kept" = true ]; then
		{
			[ -z "$send_outcome" ] || printf 'Sent to MINDY: %s\n' "$send_outcome"
			printf 'Said to the member: %s\n' "$said_line"
		} | redact >>"$stop_file" 2>/dev/null || :
	fi
}

# The download server's own sentence from an error answer, when it gave one.
server_error() {
	sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -n 1
}

# An answer other than 200. The script never shows the download server's own words. Three of the
# gate's answers are matched exactly, in its earlier or its current words, each to the decided message
# for it (the gate's rules are build-machine-stack src/mindy-gate-rules.js; it refuses with 403 and
# limits with 429): the code was not issued, the code is no longer active (its answer for a revoked or
# expired code too), and too many tries. Any other answer, whether from the gate or from something in
# the way such as a proxy, stops with the status alone as the reason shown. The stop note and the
# report keep the answer's own message after the status, and the note keeps the whole answer.
# stop_for_status <status> <answer file>
stop_for_status() {
	message=$(server_error "$2")
	status_reason="the answer was status $1"
	case "$1" in
		401|403)
			if is_gate_not_issued "$message"; then stop_saying "$not_issued_message" "$status_reason: $message"; fi
			if is_gate_not_active "$message"; then stop_saying "$not_active_message" "$status_reason: $message"; fi ;;
		429)
			if is_gate_too_many "$message"; then stop_saying "$too_many_message" "$status_reason: $message"; fi ;;
	esac
	member_reason=$status_reason
	kept_message=$(printf '%s\n' "$message" | first_meaningful)
	if [ -n "$kept_message" ]; then stop "$status_reason: $kept_message"; fi
	stop "$status_reason"
}

# The enrol and install steps ask the gate for themselves, and pass the gate's two code sentences on
# inside their own answer. Either one stops with the decided message for it, as on the direct route.
# Only the step's reason line is read for them, so a sentence elsewhere in its output, such as an
# earlier answer it repeats, does not stand in for why the step stopped.
# stop_for_gate_sentence <step output> <exit status of the step's command>
stop_for_gate_sentence() {
	gate_reason=$(reason_of "$1")
	for gate_sentence in "$gate_not_issued_sentence" "$gate_not_issued_sentence_now"; do
		case "$gate_reason" in *"$gate_sentence"*) stop_saying "$not_issued_message" "$gate_reason" "$2" ;; esac
	done
	for gate_sentence in "$gate_not_active_sentence" "$gate_not_active_sentence_now"; do
		case "$gate_reason" in *"$gate_sentence"*) stop_saying "$not_active_message" "$gate_reason" "$2" ;; esac
	done
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
	stop_time
	file_stamp=$(printf '%s\n' "$stop_stamp" | tr ':' '-')
	stop_file="$stops/$file_stamp.txt"
	[ ! -e "$stop_file" ] || stop_file="$stops/$file_stamp-$$.txt"
	if [ -n "$stop_status" ]; then step_status_text=$stop_status
	elif [ -n "$signal" ]; then step_status_text="none, $(signal_named) stopped it"
	else step_status_text='none, a check stopped it'; fi
	if keep_error=$( (
		umask 077
		{
			printf '%s\n' 'MINDY setup stop'
			printf 'Time (UTC): %s\n' "$stop_stamp"
			printf 'Report id: %s\n' "$report_id"
			printf 'App: %s\n' "$(app_name)"
			printf 'Step: %s\n' "$step"
			printf 'Reason: %s\n' "$stop_reason"
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
			member_reason=
			if [ -n "$signal" ]; then
				stop_status=
				stop_reason="it was stopped by $(signal_named)"
			else
				stop_status=$exit_status
				stop_reason=$(reason_of "$tmp/step.err")
				[ -n "$stop_reason" ] || stop_reason="a command stopped with exit status $exit_status"
			fi
			tell "$exit_status"
		elif [ "$told" = false ] && [ -n "$signal" ]; then
			# A signal stopped setup while it was sending a stop's details, before it said anything.
			say "$interrupted_message" || :
			told=true
			[ "${note_kept:-false}" = false ] || printf 'Said to the member: %s\n' "$interrupted_message" | redact >>"$stop_file" 2>/dev/null || :
		fi
		keep_stop "$exit_status" || :
		if [ -n "$archive" ] && [ -f "$archive" ]; then rm -f "$archive"; fi
		if [ "$created_version_dir" = true ] && [ -n "$version_dir" ]; then rm -rf "$version_dir"; fi
	fi
	if [ -n "$tmp" ]; then rm -rf "$tmp"; fi
}
trap cleanup EXIT
# The signal that stopped setup, as words: "an INT signal", "a TERM signal".
signal_named() {
	case "$signal" in INT) printf '%s\n' 'an INT signal' ;; *) printf 'a %s signal\n' "$signal" ;; esac
}
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
if status=$(gate_curl -sS -H 'Accept: application/json' -o "$packument" -w '%{http_code}' 'https://gate.mindy.build/mindy' 2>"$tmp/curl-packument.err"); then :; else
	stop_for_curl "$?" "$tmp/curl-packument.err"
fi
[ "$status" = 200 ] || stop_for_status "$status" "$packument"
# A 200 answer that is not MINDY's release list at all, such as a Wi-Fi sign-in page, says so.
if ! grep -q '"dist-tags"[[:space:]]*:' "$packument" 2>/dev/null; then
	answer_start=$(reason_of "$packument")
	if [ -n "$answer_start" ]; then member_reason="the answer is not MINDY's release list"; stop "$member_reason; it begins: $answer_start"; fi
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
if status=$(gate_curl -sS -o "$archive" -w '%{http_code}' "https://gate.mindy.build/mindy/-/mindy-$version.tgz" 2>"$tmp/curl-archive.err"); then :; else
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
	if [ "$message" = "$engine_different_code_sentence" ] || [ "$message" = "$engine_different_code_sentence_before" ]; then stop_saying "$different_code_message" "$message" "$enrol_status"; fi
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
