# hop

```
         _       _    _            _      
        / /\    / /\ /\ \         /\ \    
       / / /   / / //  \ \       /  \ \   
      / /_/   / / // /\ \ \     / /\ \ \  
     / /\ \__/ / // / /\ \ \   / / /\ \_\ 
    / /\ \___\/ // / /  \ \_\ / / /_/ / / 
   / / /\/___/ // / /   / / // / /__\/ /  
  / / /   / / // / /   / / // / /_____/   
 / / /   / / // / /___/ / // / /          
/ / /   / / // / /____\/ // / /           
\/_/    \/_/ \/_________/ \/_/            
                                          
```

Jump to the git worktree holding a branch.

![hop demo](docs/demo.gif)

If you use a lot of worktrees, especially with agents, you might not always
know where a branch is checked out locally.

Sure you can use `git worktree list`, but it's still tedious to list, cross
reference, then cd into the worktree.

`hop` is just a simple CLI tool that searches your repositories to find a
given branch and `cd` into that worktree for you.

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

The installer asks where you keep your repos, guessing from the conventional
directories (`~/Code`, `~/src`, `~/Projects`, …) by counting git repos in each:

```
hop-install: which directory holds your git repos? [~/Projects]
```

Press Enter to take the guess, or type a path (`~` works). It writes that as
`HOP_CODE_ROOT` in your `.zshrc`. To skip the question — for a scripted or
unattended install — set it yourself:

```sh
curl -fsSL https://raw.githubusercontent.com/Syntaf/hop/main/install.sh | HOP_CODE_ROOT=~/src bash
```

With no terminal to prompt on, it uses the guess and tells you how to change it,
rather than hanging.

Then open a new shell. The installer puts `hop-resolve` in `~/.local/bin`,
`hop.zsh` in `~/.config/hop`, and adds a short block to your `.zshrc`. It is
idempotent — re-run it to upgrade, and it will leave an existing config alone
rather than re-asking. To uninstall, delete those two files and that block.

Requires zsh, bash 3.2+ (macOS stock is fine), git, and curl.

Pin a version with `HOP_REF`, and change where things land with `HOP_BIN_DIR` /
`HOP_CONF_DIR`:

```sh
curl -fsSL https://raw.githubusercontent.com/Syntaf/hop/main/install.sh | HOP_REF=v0.1.0 bash
```

`HOP_REF` is what pins the version — fetching `install.sh` from a tag URL alone
does not, since the script then fetches its payload from `main`. Note also that
`raw.githubusercontent.com` caches for a few minutes, so an install run
immediately after a push may get the previous commit.

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
| `HOP_CODE_ROOT` | where to scan for repos; set by the installer (default `~/Code`) |
| `HOP_CACHE_TTL` | seconds to cache the scan (default `0` = always fresh) |
| `HOP_BANNER` | `0`, `off` or `no` to skip the arrival block |
| `NO_COLOR` | honoured; colour is also dropped when piped |

Repos are found by looking for `.git` one and two levels below
`HOP_CODE_ROOT` — so `~/Code/myrepo` and `~/Code/scratch/myrepo` both work.
