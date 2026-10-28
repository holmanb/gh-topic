#!/usr/bin/env bash
# Test harness helpers for the gh-topic suite. Sourced by run-tests.sh.
# Runs commands in the CURRENT shell so counters propagate.
# topic() captures stdout, stderr, and rc of a gh-topic invocation into
# TOPIC_OUT / TOPIC_ERR / TOPIC_RC, emitted from the parent clone.

GT=${GH_TOPIC_SCRIPT:?}
TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
T_ROOT=${GH_TOPIC_TEST_ROOT:-/tmp/gh-topic-tests/t-root}
T_PARENT=${GH_TOPIC_TEST_PARENT:-/tmp/gh-topic-tests/t-parent}
T_FIXTURES=${GH_TOPIC_TEST_FIXTURES:-/tmp/gh-topic-tests/fixtures}

# parent clone whose origin points at the fork (the user's topology)
mk_parent() {
    rm -rf "$T_PARENT" "$T_ROOT"
    mkdir -p "$T_PARENT" "$T_ROOT"
    git init -q -b main "$T_PARENT"
    git -C "$T_PARENT" config user.email t@t
    git -C "$T_PARENT" config user.name t
    git -C "$T_PARENT" remote add origin "$T_FIXTURES/fork.git"
    touch "$T_PARENT/f" && git -C "$T_PARENT" add f
    git -C "$T_PARENT" commit -qm init
}

env_exports() {
    export PATH="$TESTS_DIR/stub:$PATH"
    export GH_STUB_FORK=fork/tako
    export GH_STUB_FORK_URL="$T_FIXTURES/fork.git"
    export GH_STUB_PRS="$T_FIXTURES/prs.txt"
    export GH_STUB_EDITOR_LOG="$T_FIXTURES/editor.log"
    export HOME=${GH_TOPIC_TEST_HOME:-/tmp/gh-topic-tests/home}
    export GH_TOPIC_ROOT=$T_ROOT
    mkdir -p "$HOME"
}

topic() {
    local out rc
    out=$("$GT" "$@" 2> "$T_FIXTURES/last-err") && rc=0 || rc=$?
    TOPIC_OUT=$out
    TOPIC_RC=$rc
    TOPIC_ERR=$(cat "$T_FIXTURES/last-err")
}

expect_ok() { # name, args...
    local name=$1
    shift
    topic "$@"
    if [ "$TOPIC_RC" -eq 0 ]; then
        PASS=$((PASS + 1))
        echo "ok: $name"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $name - rc=$TOPIC_RC; err: $TOPIC_ERR"
    fi
}

expect_out() { # name, substring, args...
    local name=$1 want=$2
    shift 2
    topic "$@"
    case $TOPIC_OUT in
        *"$want"*)
            PASS=$((PASS + 1))
            echo "ok: $name"
            ;;
        *)
            FAIL=$((FAIL + 1))
            echo "FAIL: $name - rc=$TOPIC_RC, out=$TOPIC_OUT, err=$TOPIC_ERR"
            ;;
    esac
}

expect_fail() { # name, substring-in-stderr, args...
    local name=$1 want=$2
    shift 2
    topic "$@"
    if [ "$TOPIC_RC" -eq 0 ]; then
        FAIL=$((FAIL + 1))
        echo "FAIL: $name - unexpectedly succeeded: $TOPIC_OUT"
        return
    fi
    case $TOPIC_ERR in
        *"$want"*)
            PASS=$((PASS + 1))
            echo "ok: $name"
            ;;
        *)
            FAIL=$((FAIL + 1))
            echo "FAIL: $name - rc=$TOPIC_RC, wanted '$want', got: $TOPIC_ERR"
            ;;
    esac
}
