# secrets/

Local, machine-specific credentials. Only this file and `Secrets.mc.example` are tracked.

- `Secrets.mc` (git-ignored): copy from `Secrets.mc.example` and set `TibberSecrets.getApiToken()`. It is compiled via `base.sourcePath` in `monkey.jungle`; store builds use `release/config/ReleaseSecrets.mc` instead.
- `developer_key.der` / `developer_key.pem` (git-ignored): your Garmin signing key. Override the location with `CIQ_SIGNING_KEY`.
