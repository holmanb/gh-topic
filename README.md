# gh-topic

Per-topic directories, addressed by PR or branch — a `gh` extension.

A topic is a directory which is associated with a branch and optionally a PR.
A topic directory name is stable for the life of the topic, so chat history
keyed to that path keeps working. Topics are local clones of the parent repo,
`gh` commands work inside the topic directory.

Topics may be created and accessed by running `gh topic <verb>` from a parent repo:

- `gh topic new <name>` — create a topic and change into it: a branch named after the topic, starting at the parent's `HEAD`.
- `gh topic goto <branch-or-pr>` — change directory, creating the topic if needed.
- `gh topic gc` — remove topics whose PRs are merged or closed.

## Usage

```bash
cd <any repo>
gh topic new my-topic --open # same, plus open-or-focus the IDE window
# work, commit…
gh pr create                # plain gh, from this point on `topic goto` works
# edit code, push
# change directories
gh topic goto my-topic      # changes directory, create topic my-topic if necessary
gh topic goto 234           # alternatively indexed by PR
gh topic goto --open 234    # same, plus open-or-focus the IDE window
gh topic gc --dry-run       # list what would be removed, non-destructively
gh topic gc                 # remove topics whose PRs have been merged or closed
gh topic gc --force         # remove even topics with unmerged changes
```

## Install

Requires `gh`, and `git`.

```bash
gh extension install holmanb/gh-topic
```

## Setup

`gh topic new` and `gh topic goto` print the topic's directory. To
automatically change directory, add a wrapper to your shell config:

### bash

Add to `.bashrc`:

```bash
gh() {
  case "$1 $2" in
  "topic new" | "topic goto")
    local dir
    dir=$(command gh topic "$2" "${@:3}") && cd "$dir"
    ;;
  *) command gh "$@" ;;
  esac
}
```

### fish

Run:

```fish
function gh
    switch "$argv[1] $argv[2]"
    case "topic new" "topic goto"
        set --local dir (command gh topic $argv[2] $argv[3..-1])
        and cd $dir
    case '*'
        command gh $argv
    end
end
funcsave gh
```

## Mapping

A worktree-based workflow is replaced as follows:

| worktree workflow | gh topic |
| --- | --- |
| `git worktree add <dir> -b <branch>`, then `cd <dir>` | `gh topic new <branch>` |
| `cd <dir>` to resume, `gh pr checkout <pr>` to review | `gh topic goto <branch-or-pr>` |
| `git worktree remove <dir>`, then `git branch -d <branch>` | `gh topic gc` |

The directory is derived from the repo and branch, so there is no location
to choose or remember (and therefore no other stored state), and `gc` reads
each PR's state instead of you recalling which topics are done.

## Notes

Topic directories live under `GH_TOPIC_ROOT` (default: `$HOME`), named
`<repo>-<branch>`.

`new --open` and `goto --open` launch an IDE, `code` by default,
configurable via `GH_TOPIC_EDITOR`.

Each topic is an independent clone with its own remotes, so fetching inside
a topic updates only that topic.

Branch names may contain `/`, which cannot appear in a directory name; `/` is
percent-encoded (`feat/x` → `<repo>-feat%2Fx`), so one branch is always one
directory.

A `goto` argument that is all digits is assumed to be a PR number, so an
all-numeric branch name (`123`) is not addressable by `goto`.

Branch names are git's, with one exception: a leading `-` is a valid git
ref but cannot be passed through any command line, so `new` and `goto`
refuse it.
