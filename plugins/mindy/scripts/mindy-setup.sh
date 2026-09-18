#!/bin/sh
set -eu

code=
if [ "${1:-}" = "--code" ] && [ "${2:-}" != "" ]; then code=$2; fi
if [ -z "$code" ]; then printf '%s\n' 'This needs your access code from Mike.'; exit 0; fi
exec 2>/dev/null

tmp=
version_dir=
created_version_dir=false
archive=
finished=false
said=false
signed_message='This download is not one Mike signed. Try again, or ask Mike.'
shelf_message="Mike's shelf is not answering right now. Try again in a few minutes."
cleanup() {
	if [ "$finished" = false ] && [ "$said" = false ]; then printf '%s\n' 'Mindy could not be set up on this machine. Ask Mike.'; said=true; fi
	if [ "$finished" = false ] && [ -n "$archive" ] && [ -f "$archive" ]; then rm -f "$archive"; fi
	if [ "$finished" = false ] && [ "$created_version_dir" = true ] && [ -n "$version_dir" ]; then rm -rf "$version_dir"; fi
	if [ -n "$tmp" ]; then rm -rf "$tmp"; fi
}
trap cleanup EXIT
trap 'cleanup; exit 1' HUP INT TERM
stop() { said=true; printf '%s\n' "$1"; exit 1; }

if [ -z "${HOME:-}" ]; then
	stop 'Mindy could not be set up on this machine. Ask Mike.'
else
	home=$HOME
fi
client_root="$home/mindy"
downloads="$home/.mindy/downloads"

tmp=$(mktemp -d) || stop 'Mindy could not be set up on this machine. Ask Mike.'
packument="$tmp/packument.json"
status=$(curl -sS -H "Authorization: Bearer $code" -H 'Accept: application/json' -o "$packument" -w '%{http_code}' 'https://gate.mindy.build/mindy' 2>"$tmp/curl-packument.err") || stop "$shelf_message"
case "$status" in
	200) ;;
	401|403) message=$(sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$packument" | head -n 1); [ -n "$message" ] || message='The code was refused. Ask Mike.'; stop "$message" ;;
	429) message=$(sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$packument" | head -n 1); [ -n "$message" ] || message="$shelf_message"; stop "$message" ;;
	*) stop "$shelf_message" ;;
esac

tags=$(sed -n 's/.*"dist-tags"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p' "$packument" | head -n 1)
version=$(printf '%s\n' "$tags" | sed -n 's/.*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$version" ] || stop "$shelf_message"
version_entry=$(sed -n "s/.*\"$version\"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p" "$packument" | head -n 1)
integrity=$(printf '%s\n' "$version_entry" | sed -n 's/.*"integrity"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
case "$integrity" in sha512-*) ;; *) stop "$shelf_message" ;; esac

active="$client_root/.mindy/release-selection/active-release.json"
active_version=
if [ -f "$active" ]; then active_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$active" | head -n 1); fi
if [ "$active_version" = "$version" ]; then finished=true; printf '%s\n' 'Mindy is already installed.'; exit 0; fi
action=install
if [ -n "$active_version" ]; then action=update; fi

mkdir -p "$downloads"
version_dir="$downloads/$version"
if [ ! -d "$version_dir" ]; then mkdir -p "$version_dir"; created_version_dir=true; fi
archive="$version_dir/mindy.tgz"
status=$(curl -sS -H "Authorization: Bearer $code" -o "$archive" -w '%{http_code}' "https://gate.mindy.build/mindy/-/mindy-$version.tgz" 2>"$tmp/curl-archive.err") || stop "$shelf_message"
[ "$status" = 200 ] || stop "$shelf_message"
actual=$(shasum -a 512 "$archive" 2>"$tmp/shasum-archive.err" | sed 's/[[:space:]].*$//')
expected=$(printf '%s\n' "${integrity#sha512-}" | openssl base64 -d -A 2>"$tmp/openssl-base64.err" | od -An -tx1 2>"$tmp/od.err" | tr -d ' \n')
[ -n "$expected" ] && [ "$actual" = "$expected" ] || stop "$shelf_message"

mkdir -p "$tmp/unpacked"
tar -xzf "$archive" -C "$tmp/unpacked" 2>"$tmp/tar.err" || stop "$signed_message"
release="$tmp/unpacked/package/release"
key="$(dirname "$0")/../keys/mindy-release-signature.pem"
openssl dgst -sha256 -verify "$key" -signature "$release/release-signature.sig" "$release/release-signature.json" >"$tmp/openssl-verify.out" 2>"$tmp/openssl-verify.err" || stop "$signed_message"
manifest_file_digest=$(shasum -a 256 "$release/release-manifest.json" 2>"$tmp/shasum-manifest.err" | sed 's/[[:space:]].*$//')
signed_manifest_file_digest=$(sed -n 's/.*"manifestFileDigest"[[:space:]]*:[[:space:]]*"sha256:\([^"]*\)".*/\1/p' "$release/release-signature.json" | head -n 1)
[ -n "$signed_manifest_file_digest" ] && [ "$manifest_file_digest" = "$signed_manifest_file_digest" ] || stop "$signed_message"

machine=$(uname -m 2>"$tmp/uname.err")
case "$machine" in arm64) arch=arm64;; x86_64) arch=x64;; *) stop "$signed_message";; esac
bun="$release/components/mindy-bun-runtime/darwin-$arch/bun"
runtime_component=$(sed -n 's/.*"componentId"[[:space:]]*:[[:space:]]*"mindy-bun-runtime"\(.*\)/\1/p' "$release/release-manifest.json" | sed 's/"componentId".*//')
runtime_entry=$(printf '%s\n' "$runtime_component" | sed -n "s|.*\({[^{}]*\"path\"[[:space:]]*:[[:space:]]*\"darwin-$arch/bun\"[^{}]*}\).*|\1|p" | head -n 1)
manifest_bun_digest=$(printf '%s\n' "$runtime_entry" | sed -n 's/.*"fileDigest"[[:space:]]*:[[:space:]]*"\(sha256:[^"]*\)".*/\1/p' | head -n 1)
[ -f "$bun" ] || stop "$signed_message"
actual_bun_digest="sha256:$(shasum -a 256 "$bun" 2>"$tmp/shasum-bun.err" | sed 's/[[:space:]].*$//')"
[ "$actual_bun_digest" = "$manifest_bun_digest" ] || stop "$signed_message"
chmod 700 "$bun" 2>"$tmp/chmod.err" || stop "$signed_message"

engine="$release/components/mindy-engine/mindy-install"
enrol="$tmp/enrol.out"
if ! "$bun" "$engine/delivery-credential-cli.ts" bootstrap-with-code --membership-code "$code" --client-root "$client_root" --harness claude-code --harness codex >"$enrol" 2>&1; then
	message=$(sed -n '1p' "$enrol")
	if [ "$message" = 'This code is not one Mike issued. Check the code in Mike'"'"'s message, or ask Mike.' ] || [ "$message" = 'This machine already has a different code. Ask Mike.' ]; then stop "$message"; fi
	stop 'Mindy could not be set up on this machine. Ask Mike.'
fi
install="$tmp/install.out"
"$bun" "$engine/delivery-cli.ts" --release-signature "$release/release-signature.json" --release-package "$archive" --operation-id "mindy-setup-$(date +%s)-$$" --action "$action" --client-root "$client_root" >"$install" 2>&1 || stop 'Mindy could not be set up on this machine. Ask Mike.'

finished=true
printf '%s\n' "Mindy is now in $client_root" 'Type /MYSETUP next.'
