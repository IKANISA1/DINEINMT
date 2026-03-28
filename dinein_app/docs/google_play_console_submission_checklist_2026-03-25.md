# Google Play Console Submission Checklist

Reviewed: 2026-03-25

This document is the operator-facing checklist for the remaining manual Google
Play submission work for version `1.0.1+2`. It is derived from the current
repository state, the verified Android release manifests, the current privacy
policies, and the signed Android artifacts already produced in this workspace.

Important:
- A post-checklist Android fix removed an unintended implicit
  `READ_PHONE_STATE` permission from the shared manifest.
- Any Android `apk` or `aab` built before that fix is stale and must not be
  uploaded to Google Play.

This does not replace the live Play Console questionnaire. Re-check every
question at upload time because Google changes those forms independently of the
binary.

## Release Snapshot

Version:
- `1.0.1+2`

Packages:
- Malta: `com.dineinmalta.app`
- Rwanda: `com.dineinrw.app`

Signed artifacts on disk:
- Malta APK: `build/app/outputs/flutter-apk/app-mt-release.apk`
- Malta AAB: `build/app/outputs/bundle/mtRelease/app-mt-release.aab`
- Rwanda APK: `build/app/outputs/flutter-apk/app-rw-release.apk`
- Rwanda AAB: `build/app/outputs/bundle/rwRelease/app-rw-release.aab`

Artifact rebuild status:
- Malta merged release manifest: refreshed after the `READ_PHONE_STATE` fix
- Malta packaged release manifest: refreshed after the `READ_PHONE_STATE` fix
- Rwanda release artifacts: rebuild still required after the same shared-manifest
  fix
- Upload bundle hashes must be recomputed after fresh post-fix builds complete

Verification already completed:
- Post-fix Malta merged and packaged release manifests are clean
- Post-fix Rwanda rebuild / validator rerun is still pending
- Dart analysis: pass
- Flutter tests: pass

## Privacy Policy URLs

Use these exact URLs in Play Console:
- Malta: `https://dineinmt.ikanisa.com/privacy`
- Rwanda: `https://dineinrw.ikanisa.com/privacy`

## Store Listing / App Content Answers

Recommended answers that can be supported from the repo:
- Contains ads: `No`
- Privacy policy: `Yes`, using the URLs above

Notes:
- No ad SDK is present in the current Flutter dependencies.
- Some reviewer-facing items cannot be finalized from source alone, including
  content rating answers, any app-access reviewer instructions, and any account
  or OTP test credentials you choose to provide.

## Data Safety Global Answers

Recommended top-level answers for both packages:
- Does the app collect or share any of the required user data types: `Yes`
- Is all user data collected by the app encrypted in transit: `Yes`
- Do you provide a way for users to request that their data is deleted: `Yes`

Deletion notes:
- The public privacy policies provide a deletion request contact path.
- Rwanda BioPay users also have an in-app profile deletion flow.

Sharing note:
- Use the live Play Console definitions carefully. This checklist treats the
  app as not sharing user data for advertising or broker-style third-party use.
  You still need to account for Firebase and any other service-provider
  processing according to Google Play's current definitions at submission time.

## Malta Data Safety Entries

Recommended Malta declarations:

`Phone number`
- Collected: `Yes`
- Shared: `No`
- Required: `Required`
- Reason: venue/admin WhatsApp OTP authentication, verification, and recovery

`Photos`
- Collected: `Yes`
- Shared: `No`
- Required: `Optional`
- Reason: venue menu capture and upload workflows

`Files and docs`
- Collected: `Yes`
- Shared: `No`
- Required: `Optional`
- Reason: venue PDF and menu-file uploads

`Crash logs`
- Collected: `Yes`
- Shared: `No`
- Required: `Required`
- Reason: Firebase Crashlytics in release builds

`Diagnostics`
- Collected: `Yes`
- Shared: `No`
- Required: `Required`
- Reason: Firebase diagnostics and runtime stability

`Device or other IDs`
- Collected: `Yes`
- Shared: `No`
- Required: `Required`
- Reason: Firebase installation and notification identifiers

Do not declare these as collected off-device for Malta:
- `Exact location`
- `Audio`
- `BioPay raw face photos`

## Rwanda Data Safety Entries

Declare all Malta rows above for Rwanda too, plus the Rwanda-only BioPay data
surface below.

`Name`
- Collected: `Yes`
- Shared: `No`
- Required: `Optional`
- Reason: payer-selected BioPay display name

`Personal info > Other info`
- Collected: `Yes`
- Shared: `No`
- Required: `Optional`
- Reason: BioPay face embedding, BioPay ID, and related profile-management data

`Phone number`
- Collected: `Yes`
- Shared: `No`
- Required: `Required`
- Reason: venue/admin OTP plus Rwanda BioPay payment-routing data

`Device or other IDs`
- Collected: `Yes`
- Shared: `No`
- Required: `Required`
- Reason: Firebase identifiers plus BioPay install identifiers used for abuse
  prevention and rate limiting

Rwanda-only inference:
- Google Play's taxonomy does not provide a dedicated biometric-template row.
- The safest current mapping is to declare the BioPay face embedding under
  `Personal info > Other info` and keep the console wording aligned with the
  Rwanda privacy policy and in-app disclosure.

Do not declare these as collected off-device for Rwanda:
- `BioPay raw face photos`
- `Audio`
- `Exact location`

## Sensitive Permission Review

Malta:
- Do not describe a camera permission use case in Malta.
- The final Malta Android package should not contain `CAMERA`,
  `READ_PHONE_STATE`, `RECORD_AUDIO`, `READ_EXTERNAL_STORAGE`, or
  `WRITE_EXTERNAL_STORAGE`.

Rwanda:
- If Play Console opens a camera-related review path, explain that camera access
  is Rwanda-only and used for BioPay face enrollment and face matching.
- State that raw captures are processed transiently on-device and deleted after
  processing.
- State that the backend stores the derived face embedding, not the raw photo.
- The final Rwanda Android package should not contain `READ_PHONE_STATE`,
  `RECORD_AUDIO`, `READ_EXTERNAL_STORAGE`, or `WRITE_EXTERNAL_STORAGE`.

## Final Manual Play Console Steps

For each package:
1. Rebuild the Android `aab` after the `READ_PHONE_STATE` removal and verify the
   final package manifest is clean.
2. Upload the `aab` file, not the APK.
3. Re-check the package name and version shown in Play Console.
4. Confirm the privacy policy URL matches the country package.
5. Complete Data safety using the package-specific guidance above.
6. If a sensitive-permission review screen appears, keep the wording aligned
   with the public privacy policy and the in-app disclosure.
7. If Google asks for reviewer instructions or demo access, provide the minimum
   guest, venue/admin OTP, and Rwanda BioPay instructions needed for review.

Package upload targets:
- Malta upload bundle: `build/app/outputs/bundle/mtRelease/app-mt-release.aab`
- Rwanda upload bundle: `build/app/outputs/bundle/rwRelease/app-rw-release.aab`

## Source References

Official references used for this checklist:
- Android Developers, Declare your app's data use:
  `https://developer.android.com/privacy-and-security/declare-data-use`
- Google Play User Data policy / prominent disclosure requirements:
  `https://support.google.com/googleplay/android-developer/answer/16944162`
- Google Play prominent disclosure help:
  `https://support.google.com/googleplay/android-developer/answer/11150561`
- Firebase Play data disclosure reference:
  `https://firebase.google.com/docs/android/play-data-disclosure`

Repository references:
- `docs/google_play_submission_permissions.md`
- `landing/privacy.html`
- `landing-rw/privacy.html`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/mt/AndroidManifest.xml`
- `android/app/src/rw/AndroidManifest.xml`
