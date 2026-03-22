# App Links Artifacts

These files are the source templates for the production host:

- `https://dineinmalta.com/.well-known/assetlinks.json`
- `https://dineinmalta.com/.well-known/apple-app-site-association`

Render the deployable artifacts into `landing/.well-known/` with:

```bash
PLAY_APP_SIGNING_SHA256="AA:BB:..." \
APPLE_TEAM_ID="ABCDE12345" \
./scripts/render_app_links.sh
```

Inputs:

1. `PLAY_APP_SIGNING_SHA256`: the Play App Signing SHA-256 fingerprint for `com.dineinmalta.app`.
2. `APPLE_TEAM_ID`: the Apple Developer Team ID that signs `com.dineinmalta.app`.

Publish the rendered files from `landing/.well-known/`.

Serve `apple-app-site-association` with `application/json` content type and no
file extension.

The mobile app is configured to handle:

- `https://dineinmalta.com/v/{slug}`
