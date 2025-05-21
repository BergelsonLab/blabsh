#!/usr/bin/env bash

# annotations-in-progress status checker
#
# This script should be run from the "annotations-in-progress" directory,
# where each top-level subfolder may or may not be a git repository containing annotation work.
# It iterates over each specified (or all) subfolders, checks the current branch
# against its remote tracking branch if it is a git repo, and reports:
#   - Not a git repository (if no .git directory)
#   - Uncommitted changes
#   - Up-to-date status
#   - Behind/ahead counts via porcelain v2
#   - Detached HEAD state
#
# Usage:
#   ./annotations_status_checker.sh [--no-fetch] [--folders <dir1> <dir2> ...]
#
# Options:
#   --no-fetch    Skip fetching updates from the remote before checking status.
#   --folders     List of subfolder names to process; if omitted, all top-level
#                 subfolders will be checked.

skip_fetch=false
folders=()

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --no-fetch)
      skip_fetch=true;;
    --folders)
      shift; folders=("$@"); break;;
    *)
      echo "Unknown option: $1" >&2; exit 1;;
  esac
  shift
done

# Default to all subdirs if none specified
if [ ${#folders[@]} -eq 0 ]; then
  mapfile -t folders < <(find . -maxdepth 1 -mindepth 1 -type d | sed 's|^\./||')
fi

for dir in "${folders[@]}"; do
  # Normalize path
  dir="${dir%/}/"

  # Check for git repo
  if [ ! -d "$dir/.git" ]; then
    echo "$dir: Not a git repository"
    continue
  fi

  # Process git repo in subshell to avoid directory side-effects
  (
    cd "$dir" || { echo "$dir: Cannot enter directory"; exit; }

    # Detect branch or detached HEAD
    ref=$(git symbolic-ref --quiet HEAD 2>/dev/null || echo "DETACHED")
    if [ "$ref" = "DETACHED" ]; then
      echo "$dir: Error: detached HEAD"
      exit
    fi
    branch=${ref#refs/heads/}

    # Check upstream existence
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
      echo "$dir: Warning: no upstream for $branch"
      echo "  To set: git branch --set-upstream-to blab_share/$branch"
      echo "  Checking uncommitted changes only"
      status2=$(git status --porcelain=2 2>&1) || { echo "$dir: Error: git status failed"; exit; }
      if echo "$status2" | grep -qE '^[12u] '; then
        echo "$dir: Uncommitted changes"
      else
        echo "$dir: No upstream, no uncommitted changes"
      fi
      exit
    fi

    # Fetch only the current branch unless skipped
    if [ "$skip_fetch" = false ]; then
      git fetch --quiet blab_share "$branch" || echo "$dir: Warning: fetch failed for branch $branch"
    fi

    # Use porcelain v2 with branch info
    status2=$(git status --porcelain=2 --branch 2>&1) || { echo "$dir: Error: git status failed"; exit; }

    # Uncommitted changes check
    if echo "$status2" | grep -qE '^[12u] '; then
      echo "$dir: Uncommitted changes"
      exit
    fi

    # Parse ahead/behind from branch.ab
    ab_line=$(echo "$status2" | grep '^# branch.ab ')
    if [[ -z "$ab_line" ]]; then
      echo "$dir: Unable to determine ahead/behind"
    else
      read ahead behind < <(echo "$ab_line" | awk '{print substr($3,2), substr($4,2)}')
      if (( behind > 0 )); then
        echo "$dir: Behind by $behind commits"
      elif (( ahead > 0 )); then
        echo "$dir: Ahead by $ahead commits"
      else
        echo "$dir: Everything up-to-date"
      fi
    fi
  )
done
