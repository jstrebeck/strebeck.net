# strebeck.net

Source for [strebeck.net](https://strebeck.net), a personal blog and project showcase for
cloud and DevOps work. The site is a static [Hugo](https://gohugo.io/) build, hosted on
GitHub Pages, and deployed automatically by GitHub Actions on every push to `main`.

This repo is itself one of the showcase projects: it is a small, complete example of a
static site with zero servers to manage and a fully automated release pipeline.

## Architecture

```
  Markdown + config          GitHub Actions               GitHub Pages
 ┌──────────────────┐    push to main   ┌───────────────┐   artifact   ┌──────────────┐
 │ content/*.md     │ ─────────────────▶│ hugo --gc     │ ────────────▶│ strebeck.net │
 │ config.toml      │                   │   --minify    │              │ (static CDN) │
 │ themes/PaperMod  │                   │ upload-pages  │              └──────────────┘
 └──────────────────┘                   └───────────────┘
```

- **Static site generator: Hugo.** Content is plain Markdown with front matter. Hugo
  renders the whole site to `public/` in well under a second, with no runtime, database,
  or application server to operate.
- **Theme: [PaperMod](https://github.com/adityatelange/hugo-PaperMod)**, pulled in as a git
  submodule under `themes/PaperMod`. Overrides live in `assets/css/extended/` (custom
  styles and a One Dark syntax-highlighting palette) and self-hosted JetBrains Mono fonts
  under `static/fonts/`, so the theme itself is never edited.
- **Hosting: GitHub Pages.** The built `public/` directory is published as a Pages
  artifact and served from GitHub's CDN under the custom domain `strebeck.net`.
- **Deployment: GitHub Actions.** `.github/workflows/hugo.yaml` builds and deploys the
  site. There is no manual release step.

### Why Hugo

- Posts are Markdown files, so writing and versioning content is the same as writing code.
- A single binary with no dependency tree. The CI job installs one `.deb` and runs `hugo`.
- Builds are fast enough that the full site is regenerated on every push.
- Everything is static, which means no patching, no scaling, and nothing to get compromised.

## Deployment pipeline

Every push to `main` (or a manual run from the Actions tab) triggers two jobs:

1. **build**
   - Installs Hugo extended `0.147.0` and Dart Sass.
   - Checks out the repo with submodules so the theme is present.
   - Runs `actions/configure-pages` to resolve the Pages base URL.
   - Builds with `hugo --gc --minify --baseURL <pages url>` in `production` mode.
   - Uploads `public/` with `actions/upload-pages-artifact`.
2. **deploy**
   - Runs after `build` succeeds and publishes the artifact with `actions/deploy-pages`
     to the `github-pages` environment.

Notable details:

- The workflow uses the `GITHUB_TOKEN` with `pages: write` and `id-token: write`, so no
  long-lived secrets are stored in the repo.
- A `pages` concurrency group ensures only one deployment runs at a time. In-progress
  deployments are never cancelled, so a partially applied release cannot occur.
- The deploy job is tied to the `github-pages` environment, which surfaces the live URL on
  each workflow run.

### Container build

A multi-stage `Dockerfile` is also included for running the site outside GitHub Pages.
Stage one builds the site with Hugo on Alpine; stage two copies `public/` into an
`nginx:alpine` image that serves it on port 80.

```bash
docker build -t strebeck.net .
docker run -p 8080:80 strebeck.net
```

## Local development

```bash
# Clone with the theme submodule
git clone --recurse-submodules git@github.com:jstrebeck/strebeck.net.git
cd strebeck.net

# Live-reloading dev server at http://localhost:1313 (includes drafts)
hugo server -D        # or: make serve

# Production build, matching CI
hugo --gc --minify

# Start a new post
hugo new posts/my-post-title.md
```

New posts start as drafts. Set `draft = false` (or remove the line) when the post is ready,
then push to `main` to publish.

## Repository layout

```
.github/workflows/hugo.yaml   Build and deploy pipeline
archetypes/                   Front-matter template for new posts
assets/css/extended/          Custom CSS layered on top of PaperMod
config.toml                   Site config, menus, theme params, social links
content/                      Posts and the About page (Markdown)
static/                       Fonts and images served as-is
themes/PaperMod/              Theme (git submodule, not edited directly)
Dockerfile                    Optional Hugo + nginx container build
```
