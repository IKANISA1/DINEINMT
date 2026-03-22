# App Links Artifacts

These files are the source templates for the production hosts:

- `https://dineinmalta.com/.well-known/assetlinks.json`
- `https://dineinmalta.com/.well-known/apple-app-site-association`
- `https://dineinrw.ikanisa.com/.well-known/assetlinks.json`
- `https://dineinrw.ikanisa.com/.well-known/apple-app-site-association`

Render Malta artifacts into `landing/.well-known/` with:

```bash
PLAY_APP_SIGNING_SHA256="AA:BB:..." \
APPLE_TEAM_ID="ABCDE12345" \
./scripts/render_app_links.sh --flavor mt
```

Render Rwanda artifacts into a Rwanda site root with:

```bash
PLAY_APP_SIGNING_SHA256="AA:BB:..." \
APPLE_TEAM_ID="ABCDE12345" \
./scripts/render_app_links.sh --flavor rw --output-dir ../landing-rw/.well-known
```

Inputs:

1. `PLAY_APP_SIGNING_SHA256`: the Play App Signing SHA-256 fingerprint for the selected flavor package ID.
2. `APPLE_TEAM_ID`: the Apple Developer Team ID that signs the selected flavor bundle ID.

Publish the rendered files from the chosen `.well-known/` directory.

Serve `apple-app-site-association` with `application/json` content type and no
file extension.

The mobile apps are configured to handle:

- `https://dineinmalta.com/v/{slug}`
- `https://dineinrw.ikanisa.com/v/{slug}`
