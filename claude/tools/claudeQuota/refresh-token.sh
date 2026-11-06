#!/bin/bash
# Renew one Claude Code profile's OAuth token the way Claude Code 2.1.318 does, so running sessions of that
# profile adopt the new token instead of being logged out:
#   1. hold <dir>/.oauth_refresh.lock and <realpath dir>.lock (Claude Code's refresh locks; mkdir = proper-lockfile)
#   2. re-read the Keychain under them; a token other than the one the caller saw means someone already renewed it
#   3. hold <dir>/.storage-write.lock, POST the refresh grant, re-read and compare-and-swap on the refresh token,
#      write through `security -i` on stdin (hex payload), keeping every other field
# No secret is ever an argv element. Locks are held a few seconds, far under Claude Code's 15 s / 60 s stale limits.
#
#   refresh-token.sh <config dir> <first 16 hex of sha256 of the access token the caller saw fail or expire>
# prints one word: refreshed | busy | dead | failed:<why>
set -u
DEFAULT_CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
TOKEN_URL="${CLQ_TOKEN_URL:-https://platform.claude.com/v1/oauth/token}"
SECURITY_STDIN_LIMIT=4032

dir=$1
seen=$2
token_hash() { jq -r ".claudeAiOauth.accessToken // empty" < "$tmp/$1" | tr -d '\n' | shasum -a 256 | cut -c1-16; }
svc="Claude Code-credentials-$(printf %s "$dir" | shasum -a 256 | cut -c1-8)"
acct=${USER:-$(id -un)}
real=$(cd "$dir" && pwd -P) || { echo "failed:no_dir"; exit 0; }

tmp=$(mktemp -d) || { echo "failed:tmp"; exit 0; }
chmod 700 "$tmp"
held=()
cleanup() {
	local i
	for ((i = ${#held[@]} - 1; i >= 0; i--)); do rmdir "${held[$i]}" 2>/dev/null; done
	rm -rf "$tmp"
}
trap cleanup EXIT
take() { mkdir "$1" 2>/dev/null && held+=("$1"); }
take_waiting() {
	local n
	for n in 1 2 3 4 5 6 7 8 9 10; do take "$1" && return 0; sleep 0.3; done
	return 1
}
read_creds() { security find-generic-password -a "$acct" -s "$svc" -w > "$tmp/$1" 2>/dev/null; }
field() { jq -r ".claudeAiOauth.$2 // empty" < "$tmp/$1"; }

take "$dir/.oauth_refresh.lock" || { echo busy; exit 0; }
take "$real.lock" || { echo busy; exit 0; }

read_creds cur || { echo "failed:keychain_read"; exit 0; }
[ "$(token_hash cur)" != "$seen" ] && { echo refreshed; exit 0; }
[ -n "$(field cur refreshToken)" ] || { echo dead; exit 0; }

take_waiting "$dir/.storage-write.lock" || { echo busy; exit 0; }

jq -c --arg cid "$DEFAULT_CLIENT_ID" '.claudeAiOauth | {
	grant_type: "refresh_token",
	refresh_token: .refreshToken,
	client_id: (.clientId // $cid),
	scope: (.scopes | join(" "))
}' < "$tmp/cur" > "$tmp/body"

code=$(curl -s --max-time 10 -o "$tmp/resp" -w '%{http_code}' \
	-H 'Content-Type: application/json' --data-binary @"$tmp/body" "$TOKEN_URL")
if [ "$code" != "200" ]; then
	if /usr/bin/grep -q '"invalid_grant"' "$tmp/resp" 2>/dev/null; then echo dead; else echo "failed:http_$code"; fi
	exit 0
fi
jq -e '.access_token and .expires_in' < "$tmp/resp" > /dev/null || { echo "failed:bad_reply"; exit 0; }

read_creds now || { echo "failed:keychain_reread"; exit 0; }
if [ "$(field now refreshToken)" != "$(field cur refreshToken)" ]; then echo refreshed; exit 0; fi

nowms=$(( $(date +%s) * 1000 ))
jq -c --argjson now "$nowms" --slurpfile r "$tmp/resp" '
	$r[0] as $r
	| .claudeAiOauth.accessToken = $r.access_token
	| .claudeAiOauth.refreshToken = ($r.refresh_token // .claudeAiOauth.refreshToken)
	| .claudeAiOauth.expiresAt = ($now + $r.expires_in * 1000)
	| if $r.refresh_token_expires_in then .claudeAiOauth.refreshTokenExpiresAt = ($now + $r.refresh_token_expires_in * 1000) else . end
	| if ($r.scope // "") != "" then .claudeAiOauth.scopes = ($r.scope | split(" ")) else . end
' < "$tmp/now" > "$tmp/new"

hex=$(xxd -p < "$tmp/new" | tr -d '\n')
printf 'add-generic-password -U -a "%s" -s "%s" -X "%s"\n' "$acct" "$svc" "$hex" > "$tmp/cmd"
if [ "$(wc -c < "$tmp/cmd")" -gt "$SECURITY_STDIN_LIMIT" ]; then
	cp "$tmp/new" "$dir/.clq-unsaved-credentials.json"; chmod 600 "$dir/.clq-unsaved-credentials.json"
	echo "failed:payload_too_large_saved_to_$dir/.clq-unsaved-credentials.json"; exit 0
fi
if ! security -i < "$tmp/cmd" > /dev/null 2>&1; then
	cp "$tmp/new" "$dir/.clq-unsaved-credentials.json"; chmod 600 "$dir/.clq-unsaved-credentials.json"
	echo "failed:keychain_write_saved_to_$dir/.clq-unsaved-credentials.json"; exit 0
fi

read_creds check || { echo "failed:keychain_verify"; exit 0; }
[ "$(field check accessToken)" = "$(jq -r '.access_token' < "$tmp/resp")" ] || { echo "failed:verify_mismatch"; exit 0; }
echo refreshed
