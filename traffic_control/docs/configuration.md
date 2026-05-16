# Configuration Reference

## Convars

Set these in `server.cfg` using `setr`.

| Convar                    | Type   | Default | Example                             | Description                                                                                                         |
| ------------------------- | ------ | ------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `tControlDefault`         | number | none    | `setr tControlDefault 0.5`          | Default density multiplier when no requests are active. Value 0.0–1.0. If not set, no enforcement occurs when idle. |
| `tControlPrintRequests`   | bool   | `false` | `setr tControlPrintRequests true`   | Print every density request to the server console for debugging.                                                    |
| `ars_skip_uptodate_print` | bool   | `false` | `setr ars_skip_uptodate_print true` | Suppresses the update notifier's "Up to date" message.                                                              |

## Shared Config (`Config.lua`)

| Field                         | Default     | Description                                                                                |
| ----------------------------- | ----------- | ------------------------------------------------------------------------------------------ |
| `Config.server.requestPrefix` | `"server:"` | Prefix applied to server-originated request keys to namespace them apart from client keys. |

The client side uses a hard-coded prefix `"client:"` for its request keys.
