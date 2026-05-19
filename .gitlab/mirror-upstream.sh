#!/usr/bin/env bash
# Daily upstream mirror with auto-merge-when-clean.
#
# Behavior:
#   1. Fetch upstream main + tags
#   2. Force-update local `upstream` branch to upstream/main
#   3. Try a no-edit merge of upstream into main
#      - If clean: push main (and any new tags)
#      - If conflict: abort, leave main untouched, exit non-zero so the pipeline
#        fails visibly (configured to email the project owner)
#
# Expects env:
#   UPSTREAM_URL     — defaults to https://github.com/multica-ai/multica.git
#   ORIGIN_URL       — the GitLab origin (set automatically by CI)
#   GIT_AUTHOR_NAME  — set by CI
#   GIT_AUTHOR_EMAIL — set by CI

set -euo pipefail

UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/multica-ai/multica.git}"
ORIGIN_BRANCH="main"
UPSTREAM_BRANCH="upstream"

echo "::group::context"
git --version
echo "PWD: $PWD"
echo "UPSTREAM_URL: $UPSTREAM_URL"
echo "::endgroup::"

# Ensure both refs exist locally before we start.
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git remote set-url upstream "$UPSTREAM_URL"

echo "::group::fetch"
git fetch upstream main --tags --prune --force
git fetch origin "$ORIGIN_BRANCH" "$UPSTREAM_BRANCH" --tags --prune
echo "::endgroup::"

# 1. Force-update the local `upstream` branch.
git update-ref "refs/heads/$UPSTREAM_BRANCH" "refs/remotes/upstream/main"

# 2. Check out main, try to merge upstream.
git checkout "$ORIGIN_BRANCH"
git reset --hard "origin/$ORIGIN_BRANCH"

LOCAL_HASH=$(git rev-parse HEAD)
UPSTREAM_HASH=$(git rev-parse "refs/heads/$UPSTREAM_BRANCH")

if [ "$LOCAL_HASH" = "$UPSTREAM_HASH" ]; then
  echo "main already at upstream HEAD ($UPSTREAM_HASH) — nothing to merge"
elif git merge-base --is-ancestor "$UPSTREAM_HASH" HEAD; then
  echo "main is already ahead of upstream — local fork has diverged forward"
else
  echo "::group::merging upstream into main"
  if git merge --no-edit --no-ff "$UPSTREAM_HASH" \
      -m "chore(mirror): auto-merge upstream ($(git rev-parse --short "$UPSTREAM_HASH"))"; then
    echo "merge clean"
  else
    echo "::error::merge produced conflicts; aborting and leaving main untouched"
    git merge --abort || true
    git reset --hard "origin/$ORIGIN_BRANCH"
    # Still push the updated upstream branch + new tags so they're available.
    git push origin "refs/heads/$UPSTREAM_BRANCH:refs/heads/$UPSTREAM_BRANCH" --force-with-lease
    git push origin --tags
    exit 2
  fi
  echo "::endgroup::"
fi

echo "::group::push"
# Push order matters: upstream first (always force), then main (only fast-forward
# from origin's view since we pulled it), then tags.
git push origin "refs/heads/$UPSTREAM_BRANCH:refs/heads/$UPSTREAM_BRANCH" --force-with-lease
git push origin "refs/heads/$ORIGIN_BRANCH:refs/heads/$ORIGIN_BRANCH"
git push origin --tags
echo "::endgroup::"

echo "done. main=$(git rev-parse --short HEAD) upstream=$(git rev-parse --short refs/heads/$UPSTREAM_BRANCH)"
