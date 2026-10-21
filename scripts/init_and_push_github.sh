#!/usr/bin/env bash
set -euo pipefail

REMOTE_URL="${1:-}"

if [ ! -d ".git" ]; then
  git init -b main
fi

git add .
if [ -n "$(git status --porcelain)" ]; then
  git commit -m "feat(ccsds-ttc-ip): Stage 8 v2.14 4-Pillar CCSDS Flight & EGSE RTL IP Core"
fi

if [ -n "$REMOTE_URL" ]; then
  if git remote | grep -q "^origin$"; then
    git remote set-url origin "$REMOTE_URL"
  else
    git remote add origin "$REMOTE_URL"
  fi
  git branch -M main
  git push -u origin main
else
  echo "[INFO] Local Git repository is committed and ready on branch 'main'!"
  echo "Usage: ./scripts/init_and_push_github.sh https://github.com/<your-username>/ccsds-sat-ttc-ip.git"
fi
