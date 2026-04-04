# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal blog for strebeck.net built with Hugo using the [hugo-theme-terminal](https://github.com/panr/hugo-theme-terminal) theme (included as a git submodule).

## Common Commands

```bash
# Local development server
hugo server -D          # serves at localhost:1313, -D includes draft posts

# Build static site
hugo                    # outputs to ./public/
hugo --gc --minify      # production build (matches CI)

# Create a new post
hugo new posts/my-post-title.md
```

## Deployment

- Pushes to `main` trigger GitHub Actions (`.github/workflows/hugo.yaml`) which builds with Hugo extended v0.147.0 and deploys to GitHub Pages.
- There is also a `Dockerfile` for container-based builds (multi-stage: Hugo build -> nginx serve on port 80).

## Architecture

- `config.toml` — Site configuration, menu items, theme params. English-only, uses `terminal` theme.
- `content/` — Markdown content. Posts use TOML front matter (`+++`). New posts via `hugo new` start as `draft: true` (see `archetypes/default.md`).
- `themes/terminal/` — Git submodule. Do not edit directly; changes go upstream.
- `scripts/`, `strebeck.net/`, `templates/` — Currently empty placeholder directories.

## Content Conventions

- Posts use TOML front matter (`+++` delimiters), not YAML (`---`).
- Date format in config: `MM-DD-YYYY` (`01-02-2006` in Go time format).
- Tags are lowercase arrays: `tags = ["aws", "devops", "terraform"]`.
