#!/usr/bin/env bash
# gh-topic regression suite. Builds fixtures into a scratch dir, then
# covers: new, goto (PR + branch), the fork-PR-by-number fix, gc, and
# fork PRs whose branch is absent from the parent's origin.
set -u
PASS=0
FAIL=0
GH_TOPIC_SCRIPT=${GH_TOPIC_SCRIPT:-$(cd "$(dirname "$0")/../" && pwd)/gh-topic}
export GH_TOPIC_SCRIPT
source "$(dirname "$0")/expect_lib.sh"
bash "$(dirname "$0")/mk-fixtures.sh" "$T_FIXTURES"
env_exports
mk_parent

# --- new ---
cd "$T_PARENT" || exit 1
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_out "new: prints a topic dir" "t-root" new t-new
if [ -d "$T_ROOT/gh-topic/tako-t-new" ]; then
    PASS=$((PASS + 1))
    echo "ok: new: topic dir created"
else
    FAIL=$((FAIL + 1))
    echo "FAIL: new: topic dir missing"
fi

# new does not push: no upstream
if git -C "$T_ROOT/gh-topic/tako-t-new" rev-parse --abbrev-ref "@{u}" > /dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    echo "FAIL: new: topic branch unexpectedly has an upstream"
else
    PASS=$((PASS + 1))
    echo "ok: new: topic branch has no upstream"
fi

# --- goto: PR-number argument ---
# 237 is a fork PR; its branch IS pushed to the parent's origin (fork).
# Before the fix this died with "no PR for branch"; now it must succeed.
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_ok "goto: fork PR by number creates the topic" goto 237
if [ -d "$T_ROOT/gh-topic/tako-holmanb%2Fsyschanger-digest-glob" ] &&
    [ "$(git -C "$T_ROOT/gh-topic/tako-holmanb%2Fsyschanger-digest-glob" rev-parse --abbrev-ref HEAD)" = "holmanb/syschanger-digest-glob" ]; then
    PASS=$((PASS + 1))
    echo "ok: goto: fork topic checked out (percent-encoded dir)"
else
    FAIL=$((FAIL + 1))
    echo "FAIL: goto: fork topic dir/checkout wrong"
fi

# 238 is a fork PR whose branch is NOT pushed to origin.
# Must die with the explicit cross-fork message, not "no PR for branch".
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_fail "goto: fork PR with absent branch dies with cross-fork message" \
    "cross-fork PRs are not supported" \
    goto 238

# 239: a merged base-repo PR whose head branch was deleted from origin
# (GitHub's post-merge default). Both by branch and by number, the
# deleted head must be the reported cause, before any clone is made.
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_fail "goto: merged PR's deleted head, by branch, dies" \
    "no branch deleted-head on origin (merged" \
    goto deleted-head
expect_fail "goto: merged PR's deleted head, by number, dies" \
    "no branch deleted-head on origin (merged" \
    goto 239
[ -e "$T_ROOT"/gh-topic/tako-deleted-head ] && {
    FAIL=$((FAIL + 1))
    echo "FAIL: deleted head left a dir"
} ||
    {
        PASS=$((PASS + 1))
        echo "ok: deleted head leaves no dir"
    }

# 240: a PR head named "main" — the clone's initial branch — must check
# out (-b refuses the colliding name; -B reset-and-track survives it)
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_ok "goto: PR head named main checks out anyway" goto 240
if [ "$(git -C "$T_ROOT/gh-topic/tako-main" rev-parse --abbrev-ref HEAD)" = main ] &&
    [ "$(git -C "$T_ROOT/gh-topic/tako-main" rev-parse --abbrev-ref "@{u}" 2> /dev/null)" = origin/main ]; then
    PASS=$((PASS + 1))
    echo "ok: collision head on branch, tracking origin/main"
else
    FAIL=$((FAIL + 1))
    echo "FAIL: collision head not checked out correctly"
fi

# --- validation: bad branch names must die before creating anything ---
# a branch argument passes through branch_for_pr; require_branch
# must die there, leaving no half-baked topic dir behind
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_fail "goto: empty branch name dies" \
    "is not a valid branch name" \
    goto ""
[ -e "$T_ROOT/gh-topic/tako-" ] && {
    FAIL=$((FAIL + 1))
    echo "FAIL: empty name left a dir"
} ||
    {
        PASS=$((PASS + 1))
        echo "ok: empty name leaves no dir"
    }

# leading dash: only --open is eaten as a flag, so -b reaches
# require_branch (git would run it as an option everywhere)
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_fail "goto: leading-dash name dies" \
    "is not a valid branch name" \
    goto -b
if [ -n "$(compgen -G "$T_ROOT/gh-topic/tako-*")" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL: dash name left a dir"
else
    PASS=$((PASS + 1))
    echo "ok: dash name leaves no dir"
fi

# git-level ref rule: 'a..b' is a valid filename but a bad ref
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_fail "goto: git-invalid name a..b dies" \
    "is not a valid branch name" \
    goto "a..b"

# new: all the same rules apply before the clone
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_fail "new: empty name dies" "is not a valid branch name" new ""
[ -e "$T_ROOT/gh-topic/tako-" ] && {
    FAIL=$((FAIL + 1))
    echo "FAIL: new empty left a dir"
} ||
    {
        PASS=$((PASS + 1))
        echo "ok: new empty name leaves no dir"
    }

# --open is a flag now: a bare --open is a missing name, not a bad one
expect_fail "new: bare --open dies with usage" "usage:" new --open

# a leading-dash name is still rejected: -b is no flag, so it reaches
# require_branch
expect_fail "new: leading-dash name dies" "is not a valid branch name" new -b

# the pre-fix dup: new main must not orphan a cloned dir when the
# fresh clone already has the default branch
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_fail "new: parent's default branch name dies" \
    "cannot check out main" new main
[ -e "$T_ROOT/gh-topic/tako-main" ] && {
    FAIL=$((FAIL + 1))
    echo "FAIL: new main left an orphan dir"
} ||
    {
        PASS=$((PASS + 1))
        echo "ok: failed new leaves no orphan clone"
    }

# new --open launches the editor on the fresh topic: the stub records
# its arguments, so the launch itself is asserted, not just the rc
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
rm -f "$GH_STUB_EDITOR_LOG"
expect_ok "new: --open after the name succeeds" new open-me --open
if [ "$(git -C "$T_ROOT/gh-topic/tako-open-me" rev-parse --abbrev-ref HEAD)" = open-me ] &&
    grep -q "$T_ROOT/gh-topic/tako-open-me" "$GH_STUB_EDITOR_LOG"; then
    PASS=$((PASS + 1))
    echo "ok: new --open: editor launched on the topic dir"
else
    FAIL=$((FAIL + 1))
    echo "FAIL: new --open: dir, checkout, or editor launch wrong"
fi

# flags may come in any order, as in goto
rm -f "$GH_STUB_EDITOR_LOG"
expect_ok "new: --open before the name succeeds" new --open open-me-2
if [ -d "$T_ROOT/gh-topic/tako-open-me-2" ] &&
    grep -q "$T_ROOT/gh-topic/tako-open-me-2" "$GH_STUB_EDITOR_LOG"; then
    PASS=$((PASS + 1))
    echo "ok: new --open: flag order does not matter"
else
    FAIL=$((FAIL + 1))
    echo "FAIL: new --open before the name: dir or editor launch wrong"
fi

# valid names still work: dashless, slashed, unicode; the topic dir
# is the percent-encoded branch and the branch is really checked out
for b in "fresh" "feat/x" "ümlaut"; do
    rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
    expect_ok "new: valid name $b creates a topic" new "$b"
    # dirname: branch with %25 and %2F encoding, e.g. feat/x → feat%2Fx
    d=$T_ROOT/gh-topic/tako-$(printf '%s' "$b" | sed 's/%/%25/g; s;/;%2F;g')
    # new does not push: no upstream (rule from the earlier new tests)
    if git -C "$d" rev-parse --abbrev-ref "@{u}" > /dev/null 2>&1; then
        FAIL=$((FAIL + 1))
        echo "FAIL: new $b: branch has an upstream"
    elif [ "$(git -C "$d" rev-parse --abbrev-ref HEAD)" != "$b" ]; then
        FAIL=$((FAIL + 1))
        echo "FAIL: new $b: branch not checked out"
    else
        PASS=$((PASS + 1))
        echo "ok: new $b: on branch, no upstream"
    fi
done

# 999: PR number that does not exist at all. Real gh prints its own
# error (the stub exits silently); gh-topic must fail, not create anything.
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_fail "goto: unknown PR number dies" "no PR 999" goto 999
if [ -n "$(compgen -G "$T_ROOT/gh-topic/tako-*")" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL: unknown PR left a dir"
else
    PASS=$((PASS + 1))
    echo "ok: unknown PR number leaves no dir"
fi

# --- goto: branch arguments ---
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_ok "goto: branch with a PR creates topic" goto fresh
expect_fail "goto: branch without a PR dies" "no PR for branch" goto no-such

# --- goto: an existing dir must be the topic, not a zombie ---
# a hand-made dir is not a topic at all
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT/gh-topic/tako-fresh"
expect_fail "goto: hand-made dir dies" \
    "is not checked out on fresh" \
    goto fresh
# an interrupted goto leaves a clone on its initial branch
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
git clone -q "$T_PARENT" "$T_ROOT/gh-topic/tako-fresh"
expect_fail "goto: interrupted clone dies" \
    "is not checked out on fresh" \
    goto fresh
# a real topic passes the check: create, then revisit
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
expect_ok "goto: second visit to an existing topic stays quiet" goto fresh
expect_ok "goto: third visit still fine" goto fresh

# --- gc ---
# build topics with a merged branch (my-topic), a closed one (other),
# an open one (fresh): only merged/closed should be removable
rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
topic goto my-topic > /dev/null
topic goto other > /dev/null
topic goto fresh > /dev/null
expect_out "gc: dry-run lists merged and closed topics" "my-topic" gc --dry-run
expect_out "gc: dry-run lists both removable topics" "other" gc --dry-run
case $TOPIC_OUT in
    *fresh*)
        FAIL=$((FAIL + 1))
        echo "FAIL: gc wants to remove open topic"
        ;;
    *)
        PASS=$((PASS + 1))
        echo "ok: gc keeps open topics"
        ;;
esac

# --- clone failure must not leave a dir behind ---
# a read-only topic root makes the clone fail inside clone_topic
RO=$T_FIXTURES/ro-root
rm -rf "$RO" && mkdir -p "$RO"
chmod 555 "$RO"
GH_TOPIC_ROOT=$RO expect_fail "new: clone failure dies" "cannot clone" new fail-clone
if [ -n "$(compgen -G "$RO/gh-topic/tako-*")" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL: failed clone left a dir"
else
    PASS=$((PASS + 1))
    echo "ok: failed clone leaves no dir"
fi
chmod 755 "$RO"

# --- fish wrapper, extracted from README (source of truth) ---
# a failing goto must not cd; a succeeding one must cd.
if command -v fish > /dev/null; then
    sed -n '/^```fish$/,/^```$/p' "$TESTS_DIR/../README.md" |
        sed '1d;$d' > "$T_FIXTURES/gh-from-readme.fish"
    # on failure the and-chain skips the cd, so pwd (via ;) shows the
    # shell is still in the parent
    out=$(fish -c "source $T_FIXTURES/gh-from-readme.fish
        cd $T_PARENT
        and gh topic goto no-such
        pwd" < /dev/null 2>&1 | tail -1)
    case $out in
        "$T_PARENT" | "$T_PARENT"*)
            PASS=$((PASS + 1))
            echo "ok: fish wrapper does not cd on failure"
            ;;
        *)
            FAIL=$((FAIL + 1))
            echo "FAIL: fish wrapper cd'd on failure: $out"
            ;;
    esac
    rm -rf "$T_ROOT" && mkdir -p "$T_ROOT"
    out=$(fish -c "source $T_FIXTURES/gh-from-readme.fish
        cd $T_PARENT
        and gh topic goto 237
        and pwd" < /dev/null 2>&1 | tail -1)
    case $out in
        *$T_ROOT/gh-topic/tako-holmanb%2Fsyschanger-digest-glob*)
            PASS=$((PASS + 1))
            echo "ok: fish wrapper cds into a created topic"
            ;;
        *)
            FAIL=$((FAIL + 1))
            echo "FAIL: fish wrapper did not cd into topic: $out"
            ;;
    esac
fi

echo
echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
