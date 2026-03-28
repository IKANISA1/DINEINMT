# Google Play Submission: Permissions And Declarations

Reviewed: 2026-03-25
Packages:
- `com.dineinmalta.app` (Malta / `mt`)
- `com.dineinrw.app` (Rwanda / `rw`)

This document records the Android permission posture that should go to Google
Play for both production packages and the related App content / Data safety
work that still must be completed in Play Console before uploading version 2.

The permission lists below describe the intended final Android permission
surface after the 2026-03-25 remediation work.

Important post-pass update:
- A later same-day review of the packaged APKs found an unintended implicit
  `READ_PHONE_STATE` permission added by manifest merging.
- The shared Android manifest now removes `READ_PHONE_STATE` explicitly.
- Malta was revalidated against refreshed merged and packaged release manifests.
- Rwanda still needs one fresh post-fix rebuild / manifest rerun before final
  upload so the regenerated artifact can be checked the same way.

Earlier merged release manifests were generated on 2026-03-25 with:

```bash
cd android
./gradlew :app:processMtReleaseMainManifest :app:processRwReleaseMainManifest
```

Verified merged manifests:
- `build/app/intermediates/merged_manifests/mtRelease/processMtReleaseManifest/AndroidManifest.xml`
- `build/app/intermediates/merged_manifests/rwRelease/processRwReleaseManifest/AndroidManifest.xml`

## Official Sources

- Google Play prominent disclosure guidance:
  https://support.google.com/googleplay/android-developer/answer/11150561
- Google Play Data safety guidance:
  https://support.google.com/googleplay/android-developer/answer/10787469
- Android data use guidance:
  https://developer.android.com/privacy-and-security/declare-data-use
- Android permission minimization guidance:
  https://developer.android.com/privacy-and-security/minimize-permission-requests
- Android photo picker guidance:
  https://developer.android.com/training/data-storage/shared/photopicker
- Android camera intent guidance:
  https://developer.android.com/media/camera/camera-intents
- Firebase Play data disclosure reference:
  https://firebase.google.com/docs/android/play-data-disclosure

## What Changed On 2026-03-25

1. Removed plugin-added `RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE`, and
   `READ_EXTERNAL_STORAGE` from both release artifacts.
2. Removed implied `READ_PHONE_STATE` from both release artifacts.
3. Scoped `CAMERA` to the Rwanda flavor only.
4. Removed camera feature declarations from Malta and made the Rwanda camera
   feature optional instead of mandatory.
5. Aligned the public privacy-policy work with the actual BioPay data flow:
   raw face captures are processed transiently on-device, while the backend
   stores only the derived face embedding.

## Final Android Manifest Permissions

### Malta (`com.dineinmalta.app`)

The verified `mtRelease` merged manifest contains:

1. `android.permission.INTERNET`
Reason: Supabase APIs, OTP traffic, uploads, and Firebase transport.

2. `android.permission.ACCESS_NETWORK_STATE`
Reason: Required by the Wi-Fi join flow and network-state checks.

3. `android.permission.CHANGE_NETWORK_STATE`
Reason: Required by the Android Wi-Fi connect flow.

4. `android.permission.ACCESS_FINE_LOCATION`
Reason: Required by the Android Wi-Fi / SSID flow. The app does not send guest
location off-device for venue discovery or advertising.

5. `android.permission.NEARBY_WIFI_DEVICES`
Reason: Required on Android 13+ for nearby Wi-Fi operations. Declared with
`neverForLocation`.

6. `android.permission.ACCESS_WIFI_STATE`
Reason: Required to read Wi-Fi connection state during guest venue Wi-Fi flows.

7. `android.permission.POST_NOTIFICATIONS`
Reason: Required on Android 13+ so venue/admin users can opt into operational
push notifications.

8. `android.permission.VIBRATE`
Reason: Contributed by `flutter_local_notifications` for notification behavior.

9. `android.permission.WAKE_LOCK`
Reason: Contributed by Firebase Messaging for notification delivery support.

10. `com.google.android.c2dm.permission.RECEIVE`
Reason: Contributed by Firebase Messaging for FCM delivery.

11. `com.dineinmalta.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`
Reason: Generated AndroidX internal signature permission. This is not a user
runtime permission and does not create a separate Play declaration burden.

### Rwanda (`com.dineinrw.app`)

The verified `rwRelease` merged manifest contains all Malta permissions above,
plus:

1. `android.permission.CAMERA`
Reason: Rwanda-only BioPay uses direct in-app camera APIs for face enrollment
and matching.

The verified `rwRelease` merged manifest also contains camera features with
`android:required="false"`, so the build no longer advertises camera hardware
as a hard install requirement.

## Permissions Intentionally Not Packaged

These permissions are intentionally absent from both release artifacts to reduce
review surface and keep the package aligned with actual behavior:

1. `android.permission.RECORD_AUDIO`
Not used by the app. Removed from the merged manifest even though the camera
plugin declares it.

2. `android.permission.WRITE_EXTERNAL_STORAGE`
Not used by the app. Removed from the merged manifest.

3. `android.permission.READ_EXTERNAL_STORAGE`
Not used by the app. The app relies on system pickers and the write-permission
removal prevents the legacy read permission from being implied.

4. `android.permission.READ_PHONE_STATE`
Not used by the app. Explicitly removed from the merged manifest because
`org.tensorflow.lite.gpu.api` would otherwise imply it via an old embedded
manifest target SDK.

5. `android.permission.READ_MEDIA_IMAGES`
Not declared. Venue uploads use system pickers instead of broad media access.

6. `android.permission.CHANGE_WIFI_STATE`
Not declared. The app does not directly toggle device Wi-Fi state.

7. `android.permission.CAMERA` in Malta
Not packaged in the Malta build. Android venue photo capture there uses the
system camera intent path rather than direct camera APIs.

## Runtime Permission Behavior

1. Guest venue Wi-Fi flow:
The app shows an in-app location disclosure and then requests only the Android
permissions needed for venue Wi-Fi support:
- `ACCESS_FINE_LOCATION`
- `NEARBY_WIFI_DEVICES` on Android 13+

2. Venue camera capture on Android:
The venue onboarding flow uses the system camera intent through `image_picker`.
Because Android's guidance recommends intents for this flow, Malta no longer
declares `CAMERA` for this feature.

3. Rwanda BioPay camera flow:
The Rwanda build shows an in-app BioPay camera disclosure immediately before
requesting `CAMERA`, then uses direct in-app camera capture for face enrollment
and face matching.

4. Venue/admin notifications:
Android 13+ may request `POST_NOTIFICATIONS` when the user enables the feature
path that relies on operational push alerts.

## Play Console: Declaration Scope

### Sensitive-Permission Review

1. Malta should not surface a camera permission review path, because
`CAMERA` is no longer in the packaged manifest.

2. Rwanda will surface a camera-related review path because BioPay uses direct
camera capture. The public privacy policy and in-app disclosure must explain:
- camera access is Rwanda-only
- it is used for face enrollment and face matching
- raw face captures are processed transiently on-device
- the backend stores the resulting face embedding, not the raw photo

3. Neither package should trigger a phone-state declaration path, because
`READ_PHONE_STATE` is explicitly removed from the final merged manifests.

4. Neither package should trigger a broad storage-access declaration based on
`READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, or `READ_MEDIA_*`, because
those permissions are not in the verified release artifacts.

### Data Safety: Shared Categories To Review

The following categories should be reviewed in Play Console for both packages:

1. `Phone number`
Collected for venue/admin WhatsApp OTP login, account verification, recovery,
and related support workflows.

2. `Photos`
Collected for venue menu capture/upload workflows. This applies to menu images,
not to BioPay raw face photos, which are not retained server-side.

3. `Files and docs`
Collected when venue users upload PDFs or other supported files for menu setup.

4. `Crash logs`
Collected by Firebase Crashlytics in release builds.

5. `Diagnostics`
Collected by Firebase Crashlytics and related runtime tooling.

6. `Device or other IDs`
Review Firebase Installations / FCM identifiers in Data Safety. Firebase's own
guidance notes that Crashlytics transitively includes Firebase Installations,
which automatically collects a Firebase installation ID (FID).

### Data Safety: Rwanda-Only Additional Review

The Rwanda package includes BioPay and therefore needs additional review in Play
Console and the public privacy policy for:

1. `Name`
BioPay stores the payer-selected display name.

2. `Phone number` / payment routing data
BioPay stores the Rwanda MoMo USSD string and may normalize the recipient phone
number embedded in that string for uniqueness and routing validation.

3. `Security and abuse-prevention signals`
BioPay stores client install identifiers, IP-derived hashes, device labels,
management-code hints, abuse reports, and enrollment / match audit records.

4. `Biometric template disclosure`
Google Play's Data Safety taxonomy does not provide a dedicated biometrics row.
Do not claim that BioPay uploads raw photos. The actual server-side artifact is
a face embedding derived from on-device capture. Ensure the final console
answers stay consistent with the Rwanda privacy policy and in-app disclosure.

### Data Not Collected Off Device

1. `Exact location`
The current Wi-Fi flow uses location only on-device. It is not transmitted to
DINEIN infrastructure for venue discovery or advertising.

2. `BioPay raw face photos`
The app deletes temporary capture files after deriving an embedding. The backend
stores the embedding, not the raw face image.

3. `Audio`
The app does not use microphone capture and the packaged manifests no longer
request `RECORD_AUDIO`.

4. `Phone state`
The app does not collect telephony state and the packaged manifests no longer
request `READ_PHONE_STATE`.

## Public Privacy Policy Requirements

### Malta Privacy Policy

The Malta privacy policy used in Play Console should state:

1. Location is used only for guest venue Wi-Fi support.
2. Venue users can upload/capture menu photos and PDFs for onboarding and OCR.
3. Venue/admin phone numbers are used for OTP authentication and recovery.
4. Firebase Crashlytics and Firebase Messaging support diagnostics and
operational notifications.
5. The Malta build does not provide BioPay face-payment and does not collect or
store BioPay face embeddings.

### Rwanda Privacy Policy

The Rwanda privacy policy used in Play Console should state:

1. BioPay uses camera access to capture the user's face in-app for enrollment
and payment matching.
2. Raw BioPay face captures are processed transiently on-device and temporary
capture files are deleted after processing.
3. DINEIN stores the derived face embedding, display name, MoMo USSD payment
string, and related BioPay management / abuse-prevention records.
4. Same-device BioPay management stores an owner token securely on the device;
cross-device recovery uses the BioPay ID plus management code.
5. Users can delete their BioPay profile, and DINEIN may retain limited audit
records where reasonably necessary for security, fraud prevention, abuse
handling, or legal compliance.

## Submission Checklist

1. Build and upload bundles from the verified permission set above.
2. Re-run merged manifest verification before the final upload:
```bash
cd android
./gradlew :app:processMtReleaseMainManifest :app:processRwReleaseMainManifest
```
3. Confirm Malta does not package `CAMERA`, `READ_PHONE_STATE`,
`RECORD_AUDIO`, or legacy storage permissions.
4. Confirm Rwanda packages `CAMERA` but not `READ_PHONE_STATE`,
`RECORD_AUDIO`, or legacy storage permissions.
5. Complete `Policy > App content > Data safety` separately for both packages.
6. Ensure the Malta Play listing points to `https://dineinmt.ikanisa.com/privacy`.
7. Ensure the Rwanda Play listing points to
`https://dineinrw.ikanisa.com/privacy`.
8. Ensure the Rwanda in-app BioPay disclosure appears immediately before the
camera permission request and offers a decline path.
9. If Google requests a disclosure video, record the actual permission and
consent flows from the current build, not an older artifact.
10. Re-check Play Console questions at upload time because Google can change
policy questionnaires independently of the app binary.
