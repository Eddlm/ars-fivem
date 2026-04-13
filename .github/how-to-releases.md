# GitHub Releases — How-To

The release workflow lives at `.github/workflows/release.yml`. It fires automatically when you push a version tag, builds clean zip artifacts, and publishes them as a GitHub Release.

---

## Creating a Release

```bash
# 1. Make sure main is clean and up to date
git checkout main
git pull

# 2. Tag the commit you want to release
git tag -a v1.0.0 -m "Release v1.0.0"

# 3. Push the tag — this fires the workflow
git push origin v1.0.0
```

The Actions tab on GitHub will show the workflow running. When it finishes (~1 min), the Releases page will have the new release with 8 zip attachments.

### Tag naming

Tags must start with `v` to trigger the workflow. Examples: `v1.0.0`, `v2.1.3`, `v1.0.0-beta`.

---

## Release Artifacts

Each release produces:

| File | Contents | Who it's for |
|---|---|---|
| `ars-fivem-full.zip` | All 7 modules inside `[ars-fivem]/` | Users installing the full pack |
| `racingsystem.zip` | Just `racingsystem/` | Users who only want that module |
| `performancetuning.zip` | Just `performancetuning/` | — |
| `vehiclemanager.zip` | Just `vehiclemanager/` | — |
| `customphysics.zip` | Just `customphysics/` | — |
| `customcam.zip` | Just `customcam/` | — |
| `traffic_control.zip` | Just `traffic_control/` | — |
| `proper-handling.zip` | Just `proper-handling/` | — |

The full zip unpacks as `[ars-fivem]/` — users drop it directly into their `resources/` folder and FiveM treats it as a resource category. Per-module zips unpack as the bare module folder, also dropped into `resources/`.

---

## What Gets Excluded

These are intentionally left out of all release zips:

- Dev/IDE files: `.git/`, `.gitignore`, `.gitattributes`, `.luarc.json`, `.claude/`, `types/`
- Docs/meta files: `CLAUDE.md`, `**/AGENTS.md`, `**/Docs/`, `InstelliSenseVSCode.md`, `media/`
- Dev-only module content: `proper-handling/tools/`, `customphysics/calltrees/`
- Runtime-generated files: `racingsystem/race_index.json`, `vehiclemanager/savedvehicles/*.json`

Everything else is included.

---

## Common Adjustments

### Exclude a new file or folder

Add a line to the `rsync` block in the `Stage release files` step:

```yaml
--exclude='your/path/here/' \
```

Use a trailing `/` for directories. Use `**/foldername/` to match that folder name anywhere in the tree.

### Include something currently excluded

Remove its `--exclude=` line from the rsync block.

### Add a new module

Two places to update in `release.yml`:

1. The `for module in` loop in `Build per-module zips`:
   ```bash
   for module in racingsystem performancetuning ... your-new-module; do
   ```

2. The artifact list at the end of `Create GitHub Release`:
   ```bash
   gh release create "$GITHUB_REF_NAME" \
     ...
     your-new-module.zip
   ```

### Write release notes manually

Replace `--generate-notes` in the `Create GitHub Release` step:

```bash
# Inline text
--notes "Your release notes here"

# From a file
--notes-file CHANGELOG.md
```

Without `--generate-notes` or `--notes`, the release body will be empty.

### Change the tag pattern

Edit the trigger at the top of `release.yml`:

```yaml
on:
  push:
    tags:
      - 'v*'        # current: matches v1.0.0, v2.0.0-beta, etc.
      # - 'release-*'  # alternative pattern
```

### Add a manual trigger (run without a tag)

Add `workflow_dispatch:` under `on:`:

```yaml
on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
```

This adds a "Run workflow" button in the Actions tab. Note: `$GITHUB_REF_NAME` will be the branch name instead of a tag name when triggered manually, so the release title and tag will reflect that.

---

## Deleting a Release or Tag

If you need to redo a release (caught a mistake before anyone downloaded it):

```bash
# Delete the tag locally and on remote
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0

# Re-tag and push
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

Also delete the GitHub Release itself from the Releases page before re-pushing, otherwise `gh release create` will fail because the release already exists.
