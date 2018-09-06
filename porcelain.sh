#!/bin/sh

main() {
  # --git-dir --is-inside-git-dir --is-bare-repository # --short
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return $?
  fi
  # branch format/prefix="${1:-on %s%s}"
  dirty_format="${1:-%s}" # dirty repository format
  stage_format="${2:-%s}" # staged, unstaged, unmerged...?
  clean_format="${3:-%s}" # clean repository format

  show_upstream="${PORCELAIN_UPSTREAM:-0}"

  tmpdir=$(mktemp -d -t git.status)
  tmpfile="$tmpdir/porcelain.fifo"
  mkfifo "$tmpfile"
  git status --porcelain=v2 --ignore-submodules --branch \
    >"$tmpfile" &
  # --untracked-files[=<mode>] (no, normal, default: all)
  # --ignore-submodules[=<when>] (none, untracked, dirty, default: all)

  staged_modified=0
  staged_added=0
  staged_deleted=0
  staged_renamed=0
  staged_copied=0

  unstaged_modified=0
  unstaged_added=0
  unstaged_deleted=0
  unstaged_renamed=0
  unstaged_copied=0

  unmerged=0
  untracked=0
  ignored=0

  while read -r line; do
    case "$line" in
      # https://git-scm.com/docs/git-status#_branch_headers
      "# branch.oid "*) oid="${line#\# branch.oid }" ;; # Current commit (or initial)
      "# branch.head "*) head="${line#\# branch.head }" ;; # Current branch (or detached)
      "# branch.upstream "*) upstream="${line#\# branch.upstream }" ;; # If upstream is set
      "# branch.ab "*) ab="${line#\# branch.ab }" ;; # If upstream is set and the commit is present
      # https://git-scm.com/docs/git-status#_changed_tracked_entries
      # Ordinary changed entries have the following format:
      # 1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>
      # Renamed or copied entries have the following format:
      # 2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X><score> <path><sep><origPath>
      1* | 2*) # 1: tracked, 2: renamed
        line="${line#* }"
        xy="${line%% *}"
        case "$(echo "$xy" | cut -c1)" in
          M) staged_modified=$((staged_modified + 1)) ;;
          A) staged_added=$((staged_added + 1)) ;;
          D) staged_deleted=$((staged_deleted + 1)) ;;
          R) staged_renamed=$((staged_renamed + 1)) ;;
          C) staged_copied=$((staged_copied + 1)) ;;
        esac
        case "$(echo "$xy" | cut -c2)" in
          M) unstaged_modified=$((unstaged_modified + 1)) ;;
          A) unstaged_added=$((unstaged_added + 1)) ;;
          D) unstaged_deleted=$((unstaged_deleted + 1)) ;;
          R) unstaged_renamed=$((unstaged_renamed + 1)) ;;
          C) unstaged_copied=$((unstaged_copied + 1)) ;;
        esac
        ;;
      # Unmerged entries have the following format:
      # u <xy> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>
      "u "*) unmerged=$((unmerged + 1)) ;;
      # Untracked items have the following format: ? <path>
      "? "*) untracked=$((untracked + 1)) ;;
      # Ignored items have the following format: ! <path>
      "! "*) ignored=$((ignored + 1)) ;;
      *) # echo >&2 "$line: invalid git status line"
        return 1
        ;;
    esac
  done <"$tmpfile"
  rm "$tmpfile" && rmdir "$tmpdir" # rm -R "$tmpdir"

  branch="${head:-$(echo "$oid" | cut -c-7)}"
  if [ "${show_upstream:-0}" -eq 1 ] && [ -n "$upstream" ]; then
    branch="$branch...$upstream"
  fi

  # branch.ab +<ahead> -<behind>
  ahead=0
  behind=0
  if [ -n "$ab" ]; then
    ahead="${ab% -*}"
    ahead="${ahead#+}"
    behind="${ab#+* }"
    behind="${behind#-}"
  fi
  [ "$behind" -gt 0 ] && flags="<"
  [ "$ahead" -gt 0 ] && flags=">"

  staged=$((staged_modified + staged_added + staged_deleted + staged_renamed + staged_copied))
  unstaged=$((unstaged_modified + unstaged_added + unstaged_deleted + unstaged_renamed + unstaged_copied))
  total=$((staged + unstaged + unmerged + untracked)) # + ignored

  if [ "$staged" -gt 0 ]; then
    staged_str=
    if [ "$staged_modified" -gt 0 ]; then
      staged_str="~$staged_modified"
    fi
    if [ "$staged_added" -gt 0 ]; then
      staged_str="+$staged_added"
    fi
    if [ "$staged_deleted" -gt 0 ]; then
      staged_str="-$staged_deleted"
    fi
    if [ "$staged_deleted" -gt 0 ]; then
      staged_str="-$staged_deleted"
    fi
    if [ "$staged_renamed" -gt 0 ]; then
      staged_str="—$staged_renamed"
    fi
    if [ "$staged_copied" -gt 0 ]; then
      staged_str="=$staged_copied"
    fi
    # ${unstaged}S
    [ -n "$flags" ] && flags="$flags "
    # shellcheck disable=SC2059
    flags="$flags$(printf "$stage_format" "$staged_str")"
  fi
  if [ "$unstaged" -gt 0 ]; then
    unstaged_str=
    if [ "$unstaged_modified" -gt 0 ]; then
      unstaged_str="~$unstaged_modified"
    fi
    if [ "$unstaged_added" -gt 0 ]; then
      unstaged_str="+$unstaged_added"
    fi
    if [ "$unstaged_deleted" -gt 0 ]; then
      unstaged_str="-$unstaged_deleted"
    fi
    if [ "$unstaged_deleted" -gt 0 ]; then
      unstaged_str="-$unstaged_deleted"
    fi
    if [ "$unstaged_renamed" -gt 0 ]; then
      unstaged_str="•$unstaged_renamed"
    fi
    if [ "$unstaged_copied" -gt 0 ]; then
      unstaged_str="=$unstaged_copied"
    fi
    # ${unstaged}U
    [ -n "$flags" ] && flags="$flags "
    # shellcheck disable=SC2059
    flags="$flags$(printf "$dirty_format" "$unstaged_str")"
  fi
  if [ "$unmerged" -gt 0 ]; then
    [ -n "$flags" ] && flags="$flags "
    # shellcheck disable=SC2059
    flags="$flags$(printf "$dirty_format" "${unmerged}u")"
  fi
  if [ "$untracked" -gt 0 ]; then
    [ -n "$flags" ] && flags="$flags "
    # shellcheck disable=SC2059
    flags="$flags$(printf "$dirty_format" "${untracked}?")"
  fi
  if [ "$ignored" -gt 0 ]; then
    [ -n "$flags" ] && flags="$flags "
    flags="$flags${ignored}!"
  fi

  if [ "$total" -gt 0 ]; then
    # flags="$flags*"
    branch_format="$dirty_format"
  elif [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
    branch_format="$stage_format"
  else
    branch_format="$clean_format"
  fi
  # shellcheck disable=SC2059
  branch="$(printf "$branch_format" "$branch")"

  printf "%s%s" "$branch" "$flags"

  if [ "$total" -gt 0 ]; then
    return 2
  fi
}

main "$@"