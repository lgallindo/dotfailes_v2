#!/usr/bin/env bash
set -Eeuo pipefail

git rev-parse --is-inside-work-tree >/dev/null

timestamp="$(date -Iseconds)"
commit_msg="${1:-$timestamp}"

current_branch="$(git symbolic-ref --quiet --short HEAD || true)"

if [[ -z "$current_branch" ]]; then
  echo "ERROR: detached HEAD; aborting." >&2
  exit 1
fi

if [[ -d .git/rebase-merge || -d .git/rebase-apply || -f .git/MERGE_HEAD ]]; then
  echo "ERROR: repo is in merge/rebase state; aborting." >&2
  exit 1
fi

mapfile -t branches < <(git for-each-ref --format='%(refname:short)' refs/heads/)

for branch in "${branches[@]}"; do
  echo
  echo "=== branch: $branch ==="

  git switch "$branch"

  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    git commit -m "$commit_msg"
  else
    echo "SKIP: clean working tree"
  fi

  if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    git push
  else
    git push -u origin "$branch"
  fi
done

git switch "$current_branch"

echo
echo "DONE. Restored branch: $current_branch"
