# Production Environment Checklist — DineIn

> **Every item below must be verified before a production deployment.**

## Supabase Credentials (Automated Gate)

The build script (`scripts/build_android_release.sh`) and runtime config
(`SupabaseConfig.initialize()`) both validate these automatically.

| Variable | Requirement |
|----------|-------------|
| `SUPABASE_URL` | Must start with `https://` and end with `.supabase.co` |
| `SUPABASE_ANON_KEY` | Must be a valid JWT (starts with `eyJ`) |

## WhatsApp OTP — Critical Production Flags

These flags **must be disabled in production** to prevent test-mode bypasses:

| Variable | Prod Value | Risk if Wrong |
|----------|-----------|---------------|
| `WHATSAPP_OTP_ALLOW_MOCK` | `false` | OTP codes returned in API response — full auth bypass |
| `WHATSAPP_OTP_ALLOW_TEST_OVERRIDE` | `false` | Static test code accepted for configured phone — auth bypass |
| `WHATSAPP_OTP_ALLOW_TEXT_FALLBACK` | `false` (unless template unavailable) | Falls back to plain text if template send fails |

## JWT Signing Secrets

| Variable | Requirement |
|----------|-------------|
| `DINEIN_ADMIN_SESSION_SECRET` | Strong random secret (≥ 32 chars). Must differ from venue secret. |
| `DINEIN_VENUE_SESSION_SECRET` | Strong random secret (≥ 32 chars). If unset, falls back to admin secret. **Set explicitly.** |

## Firebase Push Notifications (Optional)

| Variable | Requirement |
|----------|-------------|
| `FIREBASE_PROJECT_ID` | Real project ID |
| `FIREBASE_CLIENT_EMAIL` | Service account email |
| `FIREBASE_PRIVATE_KEY` | Service account private key (with `\n` escaping) |

If any of these are missing, push notifications are silently disabled (logged once).

## WhatsApp Cloud API

| Variable | Requirement |
|----------|-------------|
| `WHATSAPP_ACCESS_TOKEN` | Valid Meta Business API token |
| `WHATSAPP_PHONE_NUMBER_ID` | Registered phone number ID |
| `WHATSAPP_GRAPH_API_VERSION` | Default: `v22.0` |
| `WHATSAPP_TEMPLATE_NAME` | Approved template name |

## Admin WhatsApp Numbers

| Variable | Requirement |
|----------|-------------|
| `DINEIN_ADMIN_WHATSAPP_NUMBER_MT` | Malta admin phone (e.g., `+356...`) |
| `DINEIN_ADMIN_WHATSAPP_NUMBER_RW` | Rwanda admin phone (e.g., `+250...`) |

## Cron Secrets

| Variable | Requirement |
|----------|-------------|
| `VENUE_ENRICHMENT_CRON_SECRET` | Shared secret for enrichment cron invocations |
| `VENUE_IMAGE_CRON_SECRET` | Shared secret for image generation cron invocations |

## Verification Commands

```bash
# Validate release env file
./scripts/validate_release_integrations.sh --flavor mt

# Build with credential check
./scripts/build_android_release.sh --flavor mt
```
