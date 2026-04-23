# Google Play Data Safety — DineIn

This document maps the current DineIn product behavior to Google Play Data
Safety disclosures.

## App Identity

| Field | Value |
| --- | --- |
| Package (MT) | `com.dineinmalta.app` |
| Package (RW) | `com.dineinrw.app` |
| Privacy Policy MT | `https://dineinmt.ikanisa.com/privacy.html` |
| Privacy Policy RW | `https://dineinrw.ikanisa.com/privacy.html` |

## Data Collected

### Personal Information

| Data Type | Collected? | Purpose | Shared With |
| --- | --- | --- | --- |
| Name / display name | Yes | Profile, venue/admin operations | No third parties |
| Email address | Yes | Venue/admin contact and recovery | No third parties |
| Phone number | Yes | WhatsApp OTP authentication | Meta (WhatsApp API) |

### Financial Information

| Data Type | Collected? | Notes |
| --- | --- | --- |
| Payment info | No | Payments happen outside the app |
| Purchase history | No | Orders are stored, payment credentials are not |

### Location

| Data Type | Collected? | Purpose | Shared? |
| --- | --- | --- | --- |
| Precise location | Yes | Venue Wi-Fi connection assistance only | No |
| Approximate location | No | Not used | No |

### App Activity / Diagnostics

| Data Type | Collected? | Purpose | Shared With |
| --- | --- | --- | --- |
| App interactions | Yes | Guest analytics and product improvement | No |
| Crash logs | Yes | Stability monitoring | Firebase |
| Diagnostics | Yes | Performance and reliability support | Firebase |

### Device / Other Identifiers

| Data Type | Collected? | Purpose | Shared With |
| --- | --- | --- | --- |
| Device identifiers | Yes | Push notifications and abuse prevention | Firebase / internal backend |
| Advertising ID | No | Not used | — |

### Files / Media

| Data Type | Collected? | Purpose | Shared? |
| --- | --- | --- | --- |
| Photos | Yes, venue only | Menu capture / uploads | Stored in Supabase Storage |
| Files / PDFs | Yes, venue only | Menu upload and OCR | Stored in Supabase Storage |

## Third-Party SDKs

| SDK | Data Collected | Purpose |
| --- | --- | --- |
| Firebase Crashlytics | Crash logs, device/app state | Stability monitoring |
| Firebase Messaging | Push token | Venue/admin notifications |
| Firebase Core | App instance metadata | Firebase runtime support |
| Supabase Flutter | Auth/session tokens, API traffic | Backend services |
| Google Fonts | Font download requests | Typography |

## Explicit Non-Collection

- No payment credentials captured inside the app
- No special-category identity templates
- No device inbox content
- No broad media-library harvest

## Permissions Justification

| Permission | Why It Exists |
| --- | --- |
| `INTERNET` | Core app API traffic |
| `ACCESS_NETWORK_STATE` | Online/offline + Wi-Fi support |
| `CHANGE_NETWORK_STATE` | Wi-Fi connection assistance |
| `ACCESS_COARSE_LOCATION` | Android Wi-Fi support |
| `ACCESS_FINE_LOCATION` | Android Wi-Fi support |
| `NEARBY_WIFI_DEVICES` | Android 13+ Wi-Fi support |
| `ACCESS_WIFI_STATE` | Wi-Fi state checks |
| `POST_NOTIFICATIONS` | Venue/admin operational alerts |

## Permissions Not Present In Release Artifacts

- direct camera permission
- telephony or device-inbox permissions
- microphone permission
- broad storage permissions
- broad media-library permissions

## Handling Notes

- Data is encrypted in transit with TLS.
- Supabase-managed backend storage provides at-rest protection.
- Users can request deletion of their data.
- The app is not directed to children.
