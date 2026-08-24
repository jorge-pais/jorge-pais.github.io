#!/usr/bin/env bash
# build-posts.sh — builds all posts in _posts/ using pandoc
# Usage: ./tools/build-posts.sh [site_dir] [template]
set -euo pipefail

SITE="${1:-_site}"
TMPL="${2:-templates/post.html}"
POSTS_DIR="_posts"

PANDOC_FLAGS=(
  --from=markdown+smart+raw_html
  --to=html
  --template="$TMPL"
  --highlight-style=breezedark
  --mathjax
)

# collect all posts and sort them
mapfile -d '' posts < <(find "$POSTS_DIR" -name '*.md' -print0 | sort -z)
total=${#posts[@]}

for i in "${!posts[@]}"; do
  src="${posts[$i]}"
  base=$(basename "$src" .md)

  year="${base:0:4}"
  month="${base:5:2}"
  day="${base:8:2}"
  slug="${base:11}"
  slug="${slug// /-}"   # replace spaces with hyphens

  outdir="$SITE/articles/$year/$month/$day/$slug"
  mkdir -p "$outdir"
  echo "  [POST] $slug"

  nav_args=()

  # Previous post (older, lower index)
  if [[ $i -gt 0 ]]; then
    prev="${posts[$((i-1))]}"
    pbase=$(basename "$prev" .md)
    py="${pbase:0:4}"; pm="${pbase:5:2}"; pd="${pbase:8:2}"
    pslug="${pbase:11}"; pslug="${pslug// /-}"
    ptitle=$(grep -m1 '^title:' "$prev" | sed 's/^title:[[:space:]]*//;s/^"//;s/"$//')
    nav_args+=(--variable "prev_url=/articles/$py/$pm/$pd/$pslug/")
    nav_args+=(--variable "prev_title=$ptitle")
  fi

  # Next post (newer, higher index)
  if [[ $i -lt $((total-1)) ]]; then
    next="${posts[$((i+1))]}"
    nbase=$(basename "$next" .md)
    ny="${nbase:0:4}"; nm="${nbase:5:2}"; nd="${nbase:8:2}"
    nslug="${nbase:11}"; nslug="${nslug// /-}"
    ntitle=$(grep -m1 '^title:' "$next" | sed 's/^title:[[:space:]]*//;s/^"//;s/"$//')
    nav_args+=(--variable "next_url=/articles/$ny/$nm/$nd/$nslug/")
    nav_args+=(--variable "next_title=$ntitle")
  fi

  pandoc "${PANDOC_FLAGS[@]}" "${nav_args[@]}" "$src" -o "$outdir/index.html"
done
