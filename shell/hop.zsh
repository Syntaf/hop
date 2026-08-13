# hop — cd into the git worktree holding a branch. Sourced from ~/.zshrc.

hop() {
	emulate -L zsh
	local resolver=${HOP_RESOLVER:-${commands[hop-resolve]:-$HOME/.local/bin/hop-resolve}}
	if [[ ! -x $resolver ]]; then
		print -u2 "hop: resolver missing or not executable: $resolver"
		print -u2 "     set HOP_RESOLVER, or put hop-resolve on your PATH"
		return 2
	fi

	if (( $# == 0 )); then
		COLUMNS=$COLUMNS "$resolver" list
		return
	fi

	case $1 in
		-h|--help)     COLUMNS=$COLUMNS "$resolver" help; return ;;
		-l|--list)     shift; COLUMNS=$COLUMNS "$resolver" list "$@"; return ;;
		-p|--path)     shift; COLUMNS=$COLUMNS "$resolver" path "$@"; return ;;
		-r|--refresh)  COLUMNS=$COLUMNS "$resolver" refresh; return ;;
		-*)            print -u2 "hop: unknown flag $1 (try hop -h)"; return 2 ;;
	esac

	local target before=$PWD
	target=$(COLUMNS=$COLUMNS "$resolver" path "$@") || return
	[[ -n $target ]] || return 1
	cd -- "$target" || return
	case ${HOP_BANNER:-on} in
		0|off|no) ;;
		*) COLUMNS=$COLUMNS "$resolver" describe "$target" "$before" ;;
	esac
}

_hop() {
	local -a items
	if [[ ${words[CURRENT]} == -* ]]; then
		items=(-h -l -p -r)
		compadd -a items
		return
	fi
	local resolver=${HOP_RESOLVER:-${commands[hop-resolve]:-$HOME/.local/bin/hop-resolve}}
	items=(${(f)"$(HOP_CACHE_TTL=${HOP_COMPLETION_TTL:-20} $resolver branches 2>/dev/null)"})
	compadd -a items
}

(( $+functions[compdef] )) && compdef _hop hop
