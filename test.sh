#!/bin/sh

# set -e

# Load functions
SHUNIT2=1 . ./porcelain.sh

# test -z "$TMPDIR" && TMPDIR="$(mktemp -d)"
TMPDIR="${SHUNIT_TMPDIR:-$(mktemp -d)}"

test_check_git_version() {
  echo "Testing check git version"
  check_git_version
  # Git should be installed
  assertEquals 0 $?
}

test_no_git_repo() {
  testdir="$TMPDIR/porcelain-test_no_git_repo"
  mkdir "$testdir"
  cd "$testdir"
  git_status
  # Not a git repository
  assertEquals 128 $?
  cd ..
  rm -r "$testdir"
}

test_git_init() {
  testdir="$TMPDIR/porcelain-test_git_init"
  mkdir "$testdir"
  cd "$testdir"
  git init >/dev/null
  git_status >/dev/null
  # Clean git repository
  assertEquals 0 $?
  cd ..
  rm -r "$testdir"
}

test_git_init_dirty() {
  testdir="$TMPDIR/porcelain-test_git_init_dirty"
  mkdir "$testdir"
  cd "$testdir"
  git init >/dev/null
  touch dirty
  git_status >/dev/null
  # Dirty git repository
  assertEquals 2 $?
  cd ..
  rm -rf "$testdir"
}

# Load shUnit2.
# shellcheck disable=SC1091
if [ -f ./shunit2 ]; then
  . ./shunit2
elif hash shunit2 2>/dev/null; then
  . shunit2
else
  echo >&2 "shunit2: not found"
  exit 2
fi
