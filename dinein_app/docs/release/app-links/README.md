# App Links Artifacts

These files are the release templates for the production host:

- `https://dineinmalta.com/.well-known/assetlinks.json`
- `https://dineinmalta.com/.well-known/apple-app-site-association`

Before publishing them:

1. Replace `REPLACE_WITH_PLAY_APP_SIGNING_SHA256` with the Play App Signing
   SHA-256 certificate fingerprint for `com.dineinmalta.app`.
2. Replace `REPLACE_WITH_APPLE_TEAM_ID` with the Apple Developer Team ID that
   signs `com.dineinmalta.app`.
3. Serve `apple-app-site-association` with `application/json` content type and
   no file extension.

The mobile app is configured to handle:

- `https://dineinmalta.com/v/{slug}`
