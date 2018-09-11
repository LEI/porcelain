#!/bin/sh

# Load functions
SHUNIT2=1 . ./porcelain.sh

# test_main() {
#   check_git_version
#   # Git should be installed
#   assertEquals 0 $?

#   args="[%s] [%s] [%s]"
#   # shellcheck disable=SC2086
#   out="$(porcelain_git_status $args)"
#   echo "out:$out"
# }

# # FIXME: fails because SHUNIT_TMPDIR is inside a work tree
# test_no_git_repo() {
#   out="$(porcelain_git_status)"
#   # Not a git repository
#   assertEquals 128 $?
# }

test_git_init() {
  git init >/dev/null
  out="$(porcelain_git_status)"
  # Clean git repository (exit code 0)
  assertEquals "$PORCELAIN_CLEAN_CODE" $?
  assertEquals "master" "$out"
}

test_git_init_dirty() {
  git init >/dev/null
  touch dirty
  out="$(porcelain_git_status)"
  # Dirty git repository
  assertEquals "$PORCELAIN_DIRTY_CODE" $?
  assertEquals "master*" "$out"
}

TESTDIR=

oneTimeSetUp() {
  # TESTDIR="${SHUNIT_TMPDIR:-${TMPDIR:-$(mktemp -d)}}"
  if [ -z "$SHUNIT_TMPDIR" ]; then
    echo >&2 "SHUNIT_TMPDIR is undefined"
    exit 1
  fi
  TESTDIR="$SHUNIT_TMPDIR"
}

setUp() {
  mkdir "$TESTDIR/porcelain-current-test"
  cd "$TESTDIR/porcelain-current-test" || return $?
}

tearDown() {
  [ -z "$TESTDIR" ] && exit 1
  cd ..
  rm -rf "$TESTDIR/porcelain-current-test"
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
