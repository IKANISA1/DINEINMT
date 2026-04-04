# Google Play Data Safety — DineIn Malta

> This document maps all data types collected by the DineIn app to their
> purpose, sharing status, and encryption treatment. Use this to fill out the
> Google Play Console Data Safety form.

## App Identity

| Field              | Value                         |
| ------------------ | ----------------------------- |
| Package (MT)       | `com.dineinmalta.app`         |
| Package (RW)       | `com.dineinrw.app`            |
| Privacy Policy URL | https://dineinmt.ikanisa.com/privacy.html |

---

## 1. Data Collected

### 1.1 Personal Information

| Data Type              | Collected? | Purpose                       | Shared With         | Optional? | Encrypted in Transit? |
| ---------------------- | ---------- | ----------------------------- | ------------------- | --------- | --------------------- |
| Name / display name    | Yes        | Venue claim / admin profile   | No third parties    | Yes       | Yes (TLS)             |
| Email address          | Yes        | Venue/admin auth              | No third parties    | Yes       | Yes (TLS)             |
| Phone number           | Yes        | WhatsApp OTP authentication   | Meta (WhatsApp API) | Required for venue/admin | Yes (TLS) |

### 1.2 Financial Information

| Data Type           | Collected? | Notes                                                    |
| ------------------- | ---------- | -------------------------------------------------------- |
| Payment info        | **No**     | All payments are handled outside the app (cash/Revolut/MoMo) |
| Purchase history    | **No**     | We store order data, not payment data                    |

### 1.3 Location

| Data Type          | Collected? | Purpose                          | Shared? | Optional? |
| ------------------ | ---------- | -------------------------------- | ------- | --------- |
| Precise location   | Yes        | Wi-Fi connection assistance only | No      | Yes       |
| Approximate location | No       | —                                | —       | —         |

> **Important**: Location is used solely for `ACCESS_FINE_LOCATION` to
> connect to venue Wi-Fi networks on Android. It is NOT transmitted off-device
> for discovery or advertising. This must be clearly stated in the Data Safety
> form.

### 1.4 App Activity / Usage Data

| Data Type           | Collected? | Purpose                          | Shared With  | Optional? |
| ------------------- | ---------- | -------------------------------- | ------------ | --------- |
| App interactions    | Yes        | Analytics / UX improvement       | No           | No        |
| Crash logs          | Yes        | Stability monitoring             | Firebase (Google) | No   |
| Diagnostics         | Yes        | Performance monitoring           | Firebase (Google) | No   |

### 1.5 Device / Other Identifiers

| Data Type              | Collected? | Purpose                          | Shared With       |
| ---------------------- | ---------- | -------------------------------- | ----------------- |
| Device identifiers     | Yes        | Push notifications (FCM token)   | Firebase (Google) |
| Android Advertising ID | **No**     | —                                | —                 |

### 1.6 Files / Media

| Data Type          | Collected? | Purpose                          | Shared? |
| ------------------ | ---------- | -------------------------------- | ------- |
| Photos (camera)    | Yes (venue only) | Menu photo OCR upload      | Stored in Supabase Storage |
| Files (PDF)        | Yes (venue only) | Menu PDF upload            | Stored in Supabase Storage |

### 1.7 App Info and Performance

| Data Type          | Collected? | Purpose               | Shared With       |
| ------------------ | ---------- | ---------------------- | ----------------- |
| Crash logs         | Yes        | Firebase Crashlytics   | Firebase (Google) |
| Performance data   | Yes        | Firebase Performance   | Firebase (Google) |

---

## 2. Third-Party SDKs Disclosures

| SDK                           | Data Collected                        | Purpose                  |
| ----------------------------- | ------------------------------------- | ------------------------ |
| Firebase Crashlytics          | Crash logs, device info, app state    | Stability monitoring     |
| Firebase Messaging (FCM)      | FCM registration token                | Push notifications       |
| Firebase Core                 | App instance ID                       | Analytics correlation    |
| Supabase (supabase_flutter)   | Auth tokens, user session             | Backend services         |
| Google ML Kit Face Detection  | Face geometry (RW build only, BioPay) | Face-payment enrollment  |
| TFLite Flutter                | Face embeddings (RW build only)       | Face-payment matching    |
| Google Fonts                  | Font download requests                | Typography               |

> **MT build note**: Google ML Kit Face Detection and TFLite are included in
> the dependency tree but BioPay features are NOT accessible in the MT flavor.
> The Data Safety form should reflect the MT build behavior (no face data
> collected).

---

## 3. Data Handling Practices

| Practice                           | Status |
| ---------------------------------- | ------ |
| Data encrypted in transit (TLS)    | ✅ Yes |
| Data encrypted at rest             | ✅ Yes (Supabase managed) |
| Users can request data deletion    | ✅ Yes (via Settings → Delete My Data) |
| Data deletion upon request         | ✅ Yes |
| Data is not sold to third parties  | ✅ Confirmed |
| App complies with Families Policy  | N/A (not a children's app) |

---

## 4. Permissions Justification

| Permission                 | Justification                                    |
| -------------------------- | ------------------------------------------------ |
| `INTERNET`                 | Core app functionality (API calls)               |
| `ACCESS_NETWORK_STATE`     | Detect online/offline for PWA behavior           |
| `CHANGE_NETWORK_STATE`     | Wi-Fi connection for venue networks              |
| `ACCESS_FINE_LOCATION`     | Required by Android to connect to Wi-Fi networks |
| `NEARBY_WIFI_DEVICES`      | Scan/connect venue Wi-Fi on Android 13+          |
| `ACCESS_WIFI_STATE`        | Read Wi-Fi state for auto-connect feature        |
| `POST_NOTIFICATIONS`       | Push notifications for venue order alerts        |
| `CAMERA`                   | Menu photo capture (venue onboarding)            |

### Removed Permissions (tools:node="remove")
| Permission                 | Reason for removal                               |
| -------------------------- | ------------------------------------------------ |
| `RECORD_AUDIO`             | Not needed — stripped from manifest               |
| `READ_EXTERNAL_STORAGE`    | Not needed — stripped from manifest               |
| `WRITE_EXTERNAL_STORAGE`   | Not needed — stripped from manifest               |
| `READ_PHONE_STATE`         | Not needed — stripped from manifest               |

---

## 5. IARC Content Rating Answers

| Question                                    | Answer |
| ------------------------------------------- | ------ |
| Does the app contain violence?              | No     |
| Does the app contain sexual content?        | No     |
| Does the app allow user-generated content?  | No (venue menus are curated) |
| Does the app contain gambling?              | No     |
| Does the app contain controlled substances? | No (alcohol is on menus but not sold/delivered through app) |
| Does the app contain profanity?             | No     |
| Does the app target children?               | No     |

> **Expected IARC rating**: PEGI 3 / ESRB Everyone
