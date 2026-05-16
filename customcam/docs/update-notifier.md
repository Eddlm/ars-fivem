# Update Notifier

The update notifier is a lightweight **server-side** script (`UpdateNotifier.lua`) that checks whether a newer version of customcam is available on GitHub. It runs once per resource start and prints a single line to the server console.

## How It Works

1. On `onResourceStart`, a random delay of 20–40 seconds is set before checking (to avoid thundering-herd on restart).
2. A `GlobalState` flag ensures only one check runs per server session, even if the resource restarts.
3. The script fetches `fxmanifest.lua` from the `main` branch of `Eddlm/ars-fivem` on GitHub (`raw.githubusercontent.com`).
4. Parses the `version` field from the remote manifest.
5. Compares it against the local version using semantic segment comparison (major.minor.patch).
6. Prints one of:
   - `Checking for updates.... <local> > <remote> available on https://github.com/Eddlm/ars-fivem/releases` — update available.
   - `Checking for updates.... Up to date (<local>)` — no update needed.

## Convar

| Convar                    | Type | Default | Example                             | Description                                                                        |
| ------------------------- | ---- | ------- | ----------------------------------- | ---------------------------------------------------------------------------------- |
| `ars_skip_uptodate_print` | bool | `false` | `setr ars_skip_uptodate_print true` | Suppresses the "Up to date" message. Update-available messages are always printed. |

## Configuration

The update checker reads from an internal defaults table, not from `Config.lua`:

| Field       | Default           | Description                                                                   |
| ----------- | ----------------- | ----------------------------------------------------------------------------- |
| `repo`      | `Eddlm/ars-fivem` | GitHub repository to check.                                                   |
| `branch`    | `main`            | Branch to fetch the manifest from.                                            |
| `path`      | `customcam`       | Subdirectory path within the repo.                                            |
| `token`     | `""`              | Optional GitHub personal access token for private repos or rate-limit bypass. |
| `timeoutMs` | `12000`           | HTTP request timeout in milliseconds. Minimum 1000.                           |

These are hardcoded in `UpdateNotifier.lua` and are not currently exposed as convars. Edit the `CHECKER_DEFAULTS` table directly if you need to change them (e.g. pointing to a fork).
