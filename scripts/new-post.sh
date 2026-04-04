#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$REPO_ROOT/templates/post.md"
POSTS_DIR="$REPO_ROOT/content/posts"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Error: template not found at $TEMPLATE" >&2
  exit 1
fi

# Prompt for post metadata
read -rp "Title: " title
read -rp "Author: " author
read -rp "Tags (comma-separated, e.g. aws, devops, terraform): " tags_raw
read -rp "Description: " description

# Generate date in ISO 8601 with timezone offset
date=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed 's/\([+-][0-9][0-9]\)\([0-9][0-9]\)$/\1:\2/')

# Convert title to slug for filename
slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
filepath="$POSTS_DIR/${slug}.md"

if [[ -f "$filepath" ]]; then
  echo "Error: post already exists at $filepath" >&2
  exit 1
fi

# Format tags as TOML array entries: "tag1", "tag2"
tags_formatted=""
IFS=',' read -ra tag_array <<< "$tags_raw"
for i in "${!tag_array[@]}"; do
  tag=$(echo "${tag_array[$i]}" | xargs) # trim whitespace
  if [[ -n "$tag" ]]; then
    [[ -n "$tags_formatted" ]] && tags_formatted+=", "
    tags_formatted+="\"$tag\""
  fi
done

# Build post from template
content=$(<"$TEMPLATE")
content="${content//\{\{TITLE\}\}/$title}"
content="${content//\{\{DATE\}\}/$date}"
content="${content//\{\{AUTHOR\}\}/$author}"
content="${content//\{\{TAGS\}\}/$tags_formatted}"
content="${content//\{\{DESCRIPTION\}\}/$description}"

echo "$content" > "$filepath"
echo "Created: $filepath"
