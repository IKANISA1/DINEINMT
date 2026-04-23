# Google Play Submission: Permissions And Declarations

Reviewed: 2026-04-22
Packages:

- `com.dineinmalta.app` (`mt`)
- `com.dineinrw.app` (`rw`)

This document is the Android permission source of truth for the active DineIn
hospitality product.

## Current Android Permission Surface

Both Malta and Rwanda release builds share the same effective permission
surface:

1. `android.permission.INTERNET`
Reason: Supabase APIs, WhatsApp OTP flows, storage uploads, and Firebase.

2. `android.permission.ACCESS_NETWORK_STATE`
Reason: Wi-Fi join flow and online/offline checks.

3. `android.permission.CHANGE_NETWORK_STATE`
Reason: Venue Wi-Fi connection assistance.

4. `android.permission.ACCESS_COARSE_LOCATION`
Reason: Android Wi-Fi APIs may require location-scoped access to discover the
current network environment.

5. `android.permission.ACCESS_FINE_LOCATION`
Reason: Required by Android for venue Wi-Fi support. DineIn does not use this
for ads or venue discovery.

6. `android.permission.NEARBY_WIFI_DEVICES`
Reason: Android 13+ nearby Wi-Fi operations. Declared with
`neverForLocation`.

7. `android.permission.ACCESS_WIFI_STATE`
Reason: Read Wi-Fi state during venue Wi-Fi join flows.

8. `android.permission.POST_NOTIFICATIONS`
Reason: Venue and admin operational push notifications.

9. `android.permission.VIBRATE`
Reason: Notification behavior from `flutter_local_notifications`.

10. `android.permission.WAKE_LOCK`
Reason: Firebase Messaging delivery support.

11. `com.google.android.c2dm.permission.RECEIVE`
Reason: Firebase Cloud Messaging transport.

12. `<package>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`
Reason: AndroidX generated internal signature permission.

## Permissions Intentionally Not Packaged

These categories are explicitly removed or absent from release artifacts:

- direct camera permission
- microphone permission
- broad storage permissions
- telephony and device-inbox permissions
- phone-state permissions
- broad media-library permissions

Venue media capture uses system-owned camera or picker flows rather than
shipping broad device access in the manifest.

## Runtime Permission Behavior

1. Guest Wi-Fi join
The app shows an in-app disclosure and then requests only the Android
permissions required for venue Wi-Fi support.

2. Venue media capture on Android
Venue users can capture or select media through system-owned flows. No direct
camera permission is packaged in release manifests.

3. Venue/admin notifications
Android 13+ may request `POST_NOTIFICATIONS` when the user enables operational
alerts.

## Sensitive Permission Notes

- Release artifacts are limited to networking, Wi-Fi assistance, and
  notifications.
- Payments remain outside the app: cash, Revolut handoff, or MoMo USSD handoff.
- Archived material must not be used as Play Console declaration source of
  truth.

## Pre-Upload Verification

Before any Play upload:

1. Run `./scripts/validate_release_integrations.sh --flavor <mt|rw>`.
2. Verify merged release manifests for both flavors.
3. Confirm the packaged manifest contains only the permission surface listed in
   this document.
4. Confirm store Data Safety answers match [DATA_SAFETY.md](./DATA_SAFETY.md).
