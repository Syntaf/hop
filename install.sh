#!/usr/bin/env bash
set -euo pipefail

REPO="${HOP_REPO:-Syntaf/hop}"
REF="${HOP_REF:-main}"
BIN_DIR="${HOP_BIN_DIR:-$HOME/.local/bin}"
CONF_DIR="${HOP_CONF_DIR:-$HOME/.config/hop}"

say() { printf 'hop-install: %s\n' "$*" >&2; }
die() {
	printf 'hop-install: %s\n' "$*" >&2
	exit 1
}
tilde() { printf '%s' "${1/#$HOME/~}"; }

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
	if command -v curl >/dev/null 2>&1 &&
		curl -fsSL "https://raw.githubusercontent.com/$REPO/$REF/$rel" -o "$dest"; then
		return
	fi
	if command -v gh >/dev/null 2>&1 &&
		gh api "repos/$REPO/contents/$rel?ref=$REF" \
			-H 'Accept: application/vnd.github.raw' >"$dest" 2>/dev/null; then
		return
	fi
	die "could not download $rel from $REPO@$REF — check the ref, or clone the repo"
}

count_repos() {
	local root=$1 c=0 p sub
	shopt -s nullglob
	for p in "$root"/*/; do
		if [ -e "$p.git" ]; then
			c=$((c + 1))
			continue
		fi
		for sub in "$p"*/; do
			[ -e "$sub.git" ] && c=$((c + 1))
		done
	done
	shopt -u nullglob
	printf '%s' "$c"
}

# Best guess at where this person keeps repos: the conventional directory with
# the most git repos in it.
detect_root() {
	local d n best="" bestn=0
	for d in "$HOME/Code" "$HOME/code" "$HOME/src" "$HOME/dev" "$HOME/Development" \
		"$HOME/Projects" "$HOME/projects" "$HOME/work" "$HOME/repos" "$HOME/git"; do
		[ -d "$d" ] || continue
		n=$(count_repos "$d")
		if [ "$n" -gt "$bestn" ]; then
			bestn=$n
			best=$d
		fi
	done
	[ -n "$best" ] || best="$HOME/Code"
	printf '%s' "$best"
}

# Prompt on /dev/tty, never stdin: when piped from curl, stdin is this script.
ask_root() {
	local def=$1 ans tries=0 n
	while [ "$tries" -lt 3 ]; do
		tries=$((tries + 1))
		printf 'hop-install: which directory holds your git repos? [%s] ' "$(tilde "$def")" >&2
		if ! IFS= read -r ans </dev/tty 2>/dev/null; then
			printf '\n' >&2
			printf '%s' "$def"
			return
		fi
		if [ -z "$ans" ]; then
			printf '%s' "$def"
			return
		fi
		if [ "$ans" = '~' ]; then
			ans=$HOME
		elif [ "${ans#\~/}" != "$ans" ]; then
			ans="$HOME/${ans#\~/}"
		fi
		ans=${ans%/}
		if [ -d "$ans" ]; then
			n=$(count_repos "$ans")
			[ "$n" -eq 0 ] && say "note: no git repos found in $(tilde "$ans") yet"
			printf '%s' "$ans"
			return
		fi
		say "$ans is not a directory"
	done
	say "using $(tilde "$def")"
	printf '%s' "$def"
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

RC="${ZDOTDIR:-$HOME}/.zshrc"
if [ -f "$RC" ] && grep -qE '^[[:space:]]*(source|\.)[[:space:]]+.*hop\.zsh' "$RC"; then
	say "$RC already sources hop — leaving your config alone"
	say "done. run: hop -h"
	exit 0
fi

# Where the repos are. An explicit HOP_CODE_ROOT wins; otherwise ask, and fall
# back to the best guess when there is nobody to ask.
if [ -n "${HOP_CODE_ROOT:-}" ]; then
	CODE_ROOT=${HOP_CODE_ROOT%/}
	say "using HOP_CODE_ROOT=$(tilde "$CODE_ROOT")"
elif { : </dev/tty; } 2>/dev/null; then
	CODE_ROOT=$(ask_root "$(detect_root)")
else
	CODE_ROOT=$(detect_root)
	say "no terminal to prompt on; assuming repos live in $(tilde "$CODE_ROOT")"
	say "set HOP_CODE_ROOT in $RC if that is wrong"
fi

# The zsh function finds the resolver via $HOP_RESOLVER, then PATH, then
# ~/.local/bin. If this install satisfies none of those, pin it explicitly.
PIN_RESOLVER=1
case ":$PATH:" in
*":$BIN_DIR:"*) PIN_RESOLVER=0 ;;
esac
[ "$BIN_DIR" = "$HOME/.local/bin" ] && PIN_RESOLVER=0

{
	printf '\n# hop — jump to the git worktree holding a branch (hop -h for usage)\n'
	[ "$PIN_RESOLVER" -eq 1 ] && printf 'export HOP_RESOLVER=%s/hop-resolve\n' "$BIN_DIR"
	printf 'export HOP_CODE_ROOT=%s\n' "$CODE_ROOT"
	printf 'source %s/hop.zsh\n' "$CONF_DIR"
} >>"$RC"
say "added hop to $RC (HOP_CODE_ROOT=$(tilde "$CODE_ROOT"))"
[ "$PIN_RESOLVER" -eq 1 ] &&
	say "$BIN_DIR is not on your PATH, so HOP_RESOLVER was pinned too"

say "done. open a new shell (or: source $RC) then run: hop -h"
