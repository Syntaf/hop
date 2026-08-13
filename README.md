# hop

Jump to the git worktree holding a branch.

If you keep a lot of worktrees, finding the one holding a given branch means
running `git worktree list` in repo after repo — and the worktree's directory
name usually isn't the branch name. `hop` searches every repo you have at once
and `cd`s you there.

```
$ hop login-fix
  repo    webapp
  branch  feature/login-fix
  status  in sync with origin, no tracked changes
  path    ~/Code/webapp/.claude/worktrees/pr-4821-review
```

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/Syntaf/hop/main/install.sh | bash
```

If you would rather not pipe a script into a shell — reasonable — download it,
read it, then run it. The `&&` matters: without it a failed download still gets
executed.

```sh
curl -fsSL https://raw.githubusercontent.com/Syntaf/hop/main/install.sh -o hop-install.sh \
  && less hop-install.sh && bash hop-install.sh && rm hop-install.sh
```

Or from a checkout, which skips the download entirely:

```sh
git clone https://github.com/Syntaf/hop.git && cd hop && ./install.sh
```

Then open a new shell. The installer puts `hop-resolve` in `~/.local/bin`,
`hop.zsh` in `~/.config/hop`, and adds one `source` line to your `.zshrc`. It is
idempotent, so re-run it to upgrade. To uninstall, delete those two files and
that line.

Requires zsh, bash 3.2+ (macOS stock is fine), git, and curl.

Pin a version with `HOP_REF`, and change where things land with `HOP_BIN_DIR` /
`HOP_CONF_DIR`:

```sh
curl -fsSL https://raw.githubusercontent.com/Syntaf/hop/main/install.sh | HOP_REF=v0.1.0 bash
```

## Usage

```
hop <query>       cd into the matching worktree (prompts when ambiguous)
hop               list every worktree it can find
hop -l <query>    list matches without cd'ing
hop -p <query>    print the path only:  code "$(hop -p my-branch)"
hop -h            full help
```

You never name a repo — every repo under `~/Code` is searched at once. A repo
name is just an optional extra word to narrow things down: `hop webapp
login-fix`. Tab completion covers branch and worktree names.

Matching runs in tiers, best tier wins, and ties prompt you to pick rather than
guessing:

| tier | matches | example |
| --- | --- | --- |
| 1 | exact branch | `claude/fix-thing` |
| 2 | exact branch leaf | `fix-thing` |
| 3 | exact worktree directory | `pr-4821-review` |
| 4 | branch substring | `fix-th` |
| 5 | worktree directory substring | `4821` |
| 6 | every word appears somewhere | `webapp alice session` |

Worktrees in the repo you're standing in sort first.

## Creating worktrees

When no worktree holds the branch, `hop` looks for the branch itself — local
branches with no worktree, plus any remote-tracking ref already fetched — and
offers to make one:

```
$ hop session-timeout
hop: no worktree holds alice/4821-session-timeout — it is a local branch in webapp.
     create a worktree at ~/Code/webapp/.claude/worktrees/alice+4821-session-timeout? [y/N]
```

Remote-only branches are fetched first and the new local branch is set to track
them. Nothing is created without a `y/N`. If the branch is so new that no
remote-tracking ref exists, `hop` offers to fetch the repo you're standing in,
or you can name it: `hop <repo> <branch>`.

New worktrees land in `<repo>/.claude/worktrees/<branch>`, with `/` in the
branch name written as `+`. That's where Claude Code puts its worktrees; if you
keep yours elsewhere, `hop` still *finds* them (it asks git, not the
filesystem), it just creates new ones there.

## Configuration

| variable | meaning |
| --- | --- |
| `HOP_CODE_ROOT` | where to scan for repos (default `~/Code`) |
| `HOP_CACHE_TTL` | seconds to cache the scan (default `0` = always fresh) |
| `HOP_BANNER` | `0`, `off` or `no` to skip the arrival block |
| `NO_COLOR` | honoured; colour is also dropped when piped |

Repos are found by looking for `.git` one and two levels below
`HOP_CODE_ROOT` — so `~/Code/myrepo` and `~/Code/scratch/myrepo` both work.

## Notes on behaviour

A few decisions worth knowing, since they're deliberate:

- **Ambiguity always prompts.** Two repos with the same branch name give you a
  numbered picker. Non-interactive callers get the candidate list and a non-zero
  exit instead of a silently-chosen first match.
- **Untracked files are not counted.** `status` reports tracked changes only,
  because scanning for untracked files costs ~2s in a large monorepo versus
  ~0.1s without. That's why it says "no tracked changes" rather than "clean".
- **Registered-but-deleted worktrees are flagged,** not skipped, with the
  `git worktree prune` command to fix them.
- **The scan is fresh by default.** It's one parallel `git worktree list` per
  repo, ~0.15s across 30 repos. Set `HOP_CACHE_TTL` if you want it cached; a
  cache miss re-scans before reporting failure, so a just-created worktree is
  never invisible.

## Why a shell function

A process can't change its parent shell's directory, so `hop` is a zsh function
wrapping `hop-resolve`. The resolver prints a path on stdout and everything else
on stderr, which is what makes `hop -p` composable.

Bash users: `hop-resolve` itself is bash and works fine, but the `hop` function
is zsh-only. A bash wrapper would be a short addition — it isn't written yet.
