#!/usr/bin/env bash
# Publish a daily digest page to https://caliwoo.github.io/ai-news/
#
# Usage:
#   ./publish.sh YYYY-MM-DD BODY.md [AUDIO_URL]
#
#   DATE       Edition date, e.g. 2026-11-17
#   BODY       Markdown or HTML file with the digest body (no front matter required)
#   AUDIO_URL  Optional. Direct URL of that day's MP3. Use "auto" to point at
#              https://caliwoo.github.io/cali-audio/ai-news/ai-news-YYYY-MM-DD.mp3
#
# The script writes the page, builds the Hugo site, commits the source to main,
# deploys the built site to the gh-pages branch, pushes both, and waits until
# the live edition URL returns HTTP 200.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

usage() {
  echo "Usage: $0 YYYY-MM-DD BODY.md [AUDIO_URL|auto]" >&2
  exit 2
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
fi

DATE="${1:-}"
BODY="${2:-}"
AUDIO="${3:-}"

if [[ ! "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: first argument must be a date in YYYY-MM-DD form." >&2
  usage
fi

if [[ -z "$BODY" || ! -f "$BODY" ]]; then
  echo "Error: second argument must be an existing markdown or HTML file." >&2
  usage
fi

need_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: $1 is required." >&2
    exit 1
  }
}

need_bin git
need_bin python3

if ! command -v hugo >/dev/null 2>&1; then
  echo "Hugo not on PATH; installing hugo_extended to /usr/local/bin..."
  tmp="$(mktemp -d)"
  # Prefer gh when authenticated; fall back to a direct GitHub release URL.
  if command -v gh >/dev/null 2>&1; then
    gh release download v0.170.0 --repo gohugoio/hugo \
      --pattern 'hugo_extended_0.170.0_linux-amd64.tar.gz' --dir "$tmp"
  else
    curl -fsSL -o "$tmp/hugo_extended_0.170.0_linux-amd64.tar.gz" \
      "https://github.com/gohugoio/hugo/releases/download/v0.170.0/hugo_extended_0.170.0_linux-amd64.tar.gz"
  fi
  tar -xzf "$tmp"/hugo_extended_0.170.0_linux-amd64.tar.gz -C "$tmp"
  if [[ -w /usr/local/bin ]]; then
    mv "$tmp/hugo" /usr/local/bin/hugo
  else
    sudo mv "$tmp/hugo" /usr/local/bin/hugo
  fi
  rm -rf "$tmp"
fi

# Infer a readable title from the first markdown H1, else "Daily digest".
TITLE="$(python3 - "$BODY" << 'PY'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
# Strip existing front matter if the author included it.
if text.startswith("---"):
    parts = text.split("---", 2)
    if len(parts) >= 3:
        text = parts[2]
for line in text.splitlines():
    m = re.match(r"^#\s+(.+?)\s*$", line)
    if m:
        print(m.group(1).strip())
        break
else:
    print("Daily digest")
PY
)"

CONTENT_FILE="$ROOT/content/digest/${DATE}.md"
BODY_ABS="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$BODY")"

python3 - "$CONTENT_FILE" "$DATE" "$TITLE" "$AUDIO" "$BODY_ABS" << 'PY'
import sys
from pathlib import Path

dest, date, title, audio, body_path = sys.argv[1:6]
body = Path(body_path).read_text(encoding="utf-8")
if body.startswith("---"):
    parts = body.split("---", 2)
    if len(parts) >= 3:
        body = parts[2].lstrip("\n")

# Drop a leading H1 that matches the title so it is not duplicated in the page.
lines = body.splitlines()
if lines and lines[0].startswith("# "):
    heading = lines[0][2:].strip()
    if heading.lower() == title.lower():
        body = "\n".join(lines[1:]).lstrip("\n")

if audio == "auto":
    audio_line = "audio: true\n"
elif audio:
    audio_line = f"audio: \"{audio}\"\n"
else:
    audio_line = "audio: false\n"

front = (
    "---\n"
    f'title: "{title.replace(chr(34), chr(39))}"\n'
    f"date: {date}T08:00:00-05:00\n"
    f"{audio_line}"
    "---\n\n"
)
Path(dest).parent.mkdir(parents=True, exist_ok=True)
Path(dest).write_text(front + body.rstrip() + "\n", encoding="utf-8")
print(f"Wrote {dest}")
PY

echo "Building site..."
hugo --minify --cleanDestinationDir

# Keep GitHub Pages from running Jekyll over the built files.
touch "$ROOT/public/.nojekyll"

# Commit source on the current branch (main).
if [[ -z "$(git config user.name || true)" ]]; then
  git config user.name "caliwoo"
fi
if [[ -z "$(git config user.email || true)" ]]; then
  git config user.email "60906094+caliwoo@users.noreply.github.com"
fi

git add "$CONTENT_FILE"
# Also pick up incidental layout/script changes if present, but never public/.
git add -u -- content layouts static hugo.toml publish.sh README.md archetypes .gitignore 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "Publish digest ${DATE}"
else
  echo "No source changes to commit."
fi

# Deploy the built site to gh-pages without disturbing the working tree.
WORKTREE="$(mktemp -d "${TMPDIR:-/tmp}/ai-news-pages.XXXXXX")"
cleanup() { git worktree remove --force "$WORKTREE" 2>/dev/null || rm -rf "$WORKTREE"; }
trap cleanup EXIT

if git show-ref --verify --quiet refs/heads/gh-pages; then
  git worktree add --force "$WORKTREE" gh-pages
elif git ls-remote --exit-code --heads origin gh-pages >/dev/null 2>&1; then
  git fetch origin gh-pages
  git worktree add --force "$WORKTREE" -b gh-pages origin/gh-pages
else
  git worktree add --force --detach "$WORKTREE"
  git -C "$WORKTREE" checkout --orphan gh-pages
  git -C "$WORKTREE" rm -rf . >/dev/null 2>&1 || true
fi

# Replace the branch contents with the fresh build (keep .git).
find "$WORKTREE" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -a "$ROOT/public"/. "$WORKTREE"/
touch "$WORKTREE/.nojekyll"

git -C "$WORKTREE" add -A
if git -C "$WORKTREE" diff --cached --quiet; then
  echo "Built site is already up to date on gh-pages."
else
  git -C "$WORKTREE" commit -m "Deploy ${DATE}"
fi

echo "Pushing main and gh-pages..."
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git push -u origin "$CURRENT_BRANCH"
git push -u origin gh-pages

LIVE_HOME="https://caliwoo.github.io/ai-news/"
LIVE_PAGE="https://caliwoo.github.io/ai-news/${DATE}/"

echo "Waiting for ${LIVE_PAGE} to return HTTP 200..."
ok_home=0
ok_page=0
for i in $(seq 1 36); do
  page_code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$LIVE_PAGE" || true)"
  home_code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$LIVE_HOME" || true)"
  echo "  try ${i}: home=${home_code} page=${page_code}"
  if [[ "$page_code" == "200" ]]; then ok_page=1; fi
  if [[ "$home_code" == "200" ]]; then ok_home=1; fi
  if [[ $ok_page -eq 1 && $ok_home -eq 1 ]]; then
    echo "Live:"
    echo "  $LIVE_HOME"
    echo "  $LIVE_PAGE"
    exit 0
  fi
  sleep 10
done

echo "Warning: pushed successfully, but the live URL did not return 200 within ~6 minutes." >&2
echo "  Home last checked: $LIVE_HOME"
echo "  Page last checked: $LIVE_PAGE"
exit 1
