---
id: task-40
title: Fix gitignore for Phoenix digested static files
status: Done
assignee: []
created_date: '2025-08-14 10:41'
updated_date: '2025-08-14 10:46'
labels: []
dependencies: []
---

## Description

Add patterns to .gitignore to exclude Phoenix-generated digested and gzipped static files while ensuring compatibility with our Docker deployment strategy

## Problem

When running Phoenix asset-related mix tasks (like `mix phx.digest` or `mix assets.deploy`), the following build artifacts are generated in `/priv/static/` but not gitignored:

1. **Digested versions** of static files with content hashes (e.g., `favicon-91f37b602a111216f1eef3aa337ad763.ico`)
2. **Gzipped versions** of files (`.gz` files)

These are currently showing as untracked files in git. The standard Phoenix generator doesn't include patterns for these because some deployment strategies commit them, but they should typically be gitignored.

## Solution

1. **Clean existing artifacts**:
   - Run `mix phx.digest.clean --all` to remove current digested files
   - Verify source files remain intact in `/priv/static/`

2. **Add gitignore patterns**:
   ```gitignore
   # Ignore digested and gzipped versions of static files
   /priv/static/**/*-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f].*
   /priv/static/**/*.gz
   ```
   
3. **Verify deployment still works**:
   - The Dockerfile runs `mix assets.deploy` at line 71, which includes `mix phx.digest`
   - This happens during Docker build, so digested files are created fresh in the container
   - No changes needed to deployment process

## Context

- Phoenix 1.6+ places static files directly in `/priv/static/`
- Current `.gitignore` only excludes `/priv/static/assets/` and `/priv/static/cache_manifest.json`
- Phoenix team intentionally doesn't ignore these by default for deployment flexibility
- See: https://github.com/phoenixframework/phoenix/issues/4422

## Deployment Strategy

This project uses Fly.io deployment via GitHub Actions:
- **GitHub Actions**: `.github/workflows/fly-deploy.yml` triggers on push to main
- **Dockerfile**: Copies source files including `/priv/static/` at line 66
- **Asset compilation**: Runs `mix assets.deploy` during Docker build (line 71)
- **Result**: Digested files are generated fresh inside the Docker container during build

This means we can safely gitignore the digested files since they're always regenerated during deployment.
