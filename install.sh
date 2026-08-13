#!/usr/bin/env bash
set -euo pipefail

REPO="${HOP_REPO:-Syntaf/hop}"
REF="${HOP_REF:-main}"
BIN_DIR="${HOP_BIN_DIR:-$HOME/.local/bin}"
CONF_DIR="${HOP_CONF_DIR:-$HOME/.config/hop}"

say() { printf 'hop-install: %s\n' "$*"; }
die() {
	printf 'hop-install: %s\n' "$*" >&2
	exit 1
}

SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
	SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
	[ -f "$SRC/bin/hop-resolve" ] || SRC=""
fi

# Local checkout if we have one, otherwise pull the two files straight from the
# repo so this script works when piped from curl or gh.
fetch() {
	local rel=$1 dest=$2
	if [ -n "$SRC" ]; then
		cat "$SRC/$rel" >"$dest"
		return
	fi
	if command -v gh >/dev/null 2>&1; then
		gh api "repos/$REPO/contents/$rel?ref=$REF" \
			-H 'Accept: application/vnd.github.raw' >"$dest" 2>/dev/null && return
		say "gh could not read $rel from $REPO@$REF"
	fi
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL "https://raw.githubusercontent.com/$REPO/$REF/$rel" -o "$dest" && return
	fi
	die "could not download $rel — install gh (private repo) or curl, or clone the repo"
}

command -v git >/dev/null 2>&1 || die "git is required"

case "${SHELL##*/}" in
zsh) ;;
*) say "warning: your shell is ${SHELL##*/}; hop ships a zsh function only" ;;
esac

TMP=$(mktemp -d "${TMPDIR:-/tmp}/hop-install.XXXXXX") || die "cannot create temp dir"
trap 'rm -rf "$TMP"' EXIT

fetch bin/hop-resolve "$TMP/hop-resolve"
fetch shell/hop.zsh "$TMP/hop.zsh"

# A 404 or an HTML error page must not land in your PATH.
head -n1 "$TMP/hop-resolve" | grep -q '^#!/usr/bin/env bash' ||
	die "downloaded hop-resolve does not look like the script (bad ref or no access?)"
grep -q '^hop()' "$TMP/hop.zsh" ||
	die "downloaded hop.zsh does not define hop() (bad ref or no access?)"
[ -n "$SRC" ] || say "fetched hop from $REPO@$REF"

mkdir -p "$BIN_DIR" "$CONF_DIR"
install -m 755 "$TMP/hop-resolve" "$BIN_DIR/hop-resolve"
install -m 644 "$TMP/hop.zsh" "$CONF_DIR/hop.zsh"
say "installed $BIN_DIR/hop-resolve and $CONF_DIR/hop.zsh"

# The zsh function finds the resolver via $HOP_RESOLVER, then PATH, then
# ~/.local/bin. If this install satisfies none of those, pin it explicitly.
PIN_RESOLVER=1
case ":$PATH:" in
*":$BIN_DIR:"*) PIN_RESOLVER=0 ;;
esac
[ "$BIN_DIR" = "$HOME/.local/bin" ] && PIN_RESOLVER=0

RC="${ZDOTDIR:-$HOME}/.zshrc"
LINE="source $CONF_DIR/hop.zsh"
if [ -f "$RC" ] && grep -qE '^[[:space:]]*(source|\.)[[:space:]]+.*hop\.zsh' "$RC"; then
	say "$RC already sources hop"
else
	{
		printf '\n# hop — jump to the git worktree holding a branch (hop -h for usage)\n'
		[ "$PIN_RESOLVER" -eq 1 ] && printf 'export HOP_RESOLVER=%s/hop-resolve\n' "$BIN_DIR"
		printf '%s\n' "$LINE"
	} >>"$RC"
	say "added the source line to $RC"
	[ "$PIN_RESOLVER" -eq 1 ] &&
		say "$BIN_DIR is not on your PATH, so HOP_RESOLVER was pinned in $RC"
fi

if [ ! -d "${HOP_CODE_ROOT:-$HOME/Code}" ]; then
	say "note: ${HOP_CODE_ROOT:-$HOME/Code} does not exist —"
	say "      set HOP_CODE_ROOT in your shell rc to point at wherever you keep repos"
fi

say "done. open a new shell (or: source $RC) then run: hop -h"
