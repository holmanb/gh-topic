#!/usr/bin/env bash
# Build the gh-topic test fixtures into a scratch dir: a bare "fork"
# repo with the branches the PR fixtures reference, and prs.txt.
# Idempotent: wipes and rebuilds. Used by run-tests.sh.
set -u
FIXTURES=${1:?usage: mk-fixtures.sh <dir>}
rm -rf "$FIXTURES"
mkdir -p "$FIXTURES"

git init -q --bare -b main "$FIXTURES/fork.git"
git -C "$FIXTURES/fork.git" config user.email t@t
git -C "$FIXTURES/fork.git" config user.name t

# a work repo to build the branches in, then push them all
W=$FIXTURES/work
git init -q -b main "$W"
git -C "$W" config user.email t@t
git -C "$W" config user.name t
touch "$W/f" && git -C "$W" add f && git -C "$W" commit -qm init

# branches the PR fixtures reference; every branch is created in the
# graph, but 239's head was deleted on origin — GitHub's post-merge
# default — so the push list omits it: ls-remote must not see it
for b in my-topic other fresh holmanb/syschanger-digest-glob keep-main-alive main-with-pr deleted-head holmanb/merged-fork; do
    git -C "$W" branch "$b" main
done
git -C "$W" push -q "$FIXTURES/fork.git" main my-topic other fresh \
    holmanb/syschanger-digest-glob keep-main-alive main-with-pr \
    holmanb/merged-fork
rm -rf "$W"

# PR fixtures: num branch state [fork]
# 234/235 merged/closed base PRs; 236 open; 237/238 fork PRs (238's
# branch is absent from origin); 239 merged (head deleted from origin,
# per the push list above); 240 a PR head named "main".
cat > "$FIXTURES/prs.txt" << 'EOF'
234 my-topic MERGED
235 other CLOSED
236 fresh OPEN
237 holmanb/syschanger-digest-glob OPEN fork
238 gone-fork-branch OPEN fork
239 deleted-head MERGED
240 main OPEN
241 holmanb/merged-fork MERGED fork
EOF
