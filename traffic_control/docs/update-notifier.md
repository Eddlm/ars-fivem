# Update Notifier

The update notifier is a lightweight **server-side** script (`server/UpdateNotifier.lua`) that checks whether a newer version of traffic_control is available on GitHub. It runs once per resource start and prints a single line to the server console.

## How It Works

1. On `onResourceStart`, a random delay of 20–40 seconds is set before checking.
2. A `GlobalState` flag ensures only one check runs per server session, even across resource restarts.
3. The script fetches `fxmanifest.lua` from the `main` branch of `Eddlm/ars-fivem` on GitHub.
4. Parses the `version` field and compares it against the local version using semantic segment comparison.
5. Prints one of:
   - `Checking for updates.... <local> > <remote> available on https://github.com/Eddlm/ars-fivem/releases` — update available.
   - `Checking for updates.... Up to date (<local>)` — no update needed.

## Convar

| Convar                    | Type | Default | Example                             | Description                                                                          |
| ------------------------- | ---- | ------- | ----------------------------------- | ------------------------------------------------------------------------------------ |
| `ars_skip_uptodate_print` | bool | `false` | `setr ars_skip_uptodate_print true` | Suppresses the "Up to date" console message. Update-available messages always print. |

## Internal Defaults

The checker reads from a hardcoded `CHECKER_DEFAULTS` table:

| Field       | Default           | Description                                                 |
| ----------- | ----------------- | ----------------------------------------------------------- |
| `repo`      | `Eddlm/ars-fivem` | GitHub repository to check.                                 |
| `branch`    | `main`            | Branch to fetch the manifest from.                          |
| `path`      | `traffic_control` | Subdirectory within the repo.                               |
| `token`     | `""`              | Optional GitHub PAT for private repos or rate-limit bypass. |
| `timeoutMs` | `12000`           | HTTP request timeout (ms). Minimum 1000.                    |
