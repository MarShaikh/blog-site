#!/bin/zsh
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

SRC="/Users/mrfshk/Documents/Everything/Blog stuff/Posts/"
REPO="/Users/mrfshk/Documents/blog-site"
DST="$REPO/content/"
LOCK="/tmp/blog-sync.lock"

if ! mkdir "$LOCK" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK"' EXIT

cd "$REPO"

rsync -a --delete \
  --exclude '.DS_Store' --exclude '.obsidian' --exclude '.trash' \
  "$SRC" "$DST"

if [[ -n "$(git status --porcelain content/)" ]]; then
  git add content/
  git commit -m "Sync posts from Obsidian vault"
  git push origin main
fi
