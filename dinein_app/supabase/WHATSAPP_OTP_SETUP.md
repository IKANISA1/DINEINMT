# WhatsApp OTP Setup

This app uses the Supabase Edge Function `whatsapp-otp` for venue login, venue claim verification, and admin console login.

## Required remote secrets

Set these in the Supabase project:

- `WHATSAPP_ACCESS_TOKEN`
- `WHATSAPP_PHONE_NUMBER_ID`
- `WHATSAPP_TEMPLATE_NAME`
- `WHATSAPP_TEMPLATE_LANGUAGE`
- `WHATSAPP_TEMPLATE_URL_BUTTON_INDEX` if the template includes a URL button
- `WHATSAPP_OTP_PEPPER`
- `DEFAULT_WHATSAPP_COUNTRY_CODE`
- `WHATSAPP_GRAPH_API_VERSION`
- `WHATSAPP_OTP_TTL_MINUTES`
- `WHATSAPP_OTP_MAX_ATTEMPTS`
- `WHATSAPP_OTP_REQUEST_LIMIT`
- `WHATSAPP_OTP_REQUEST_WINDOW_MINUTES`
- `DINEIN_ADMIN_SESSION_SECRET`
- `DINEIN_ADMIN_SESSION_TTL_MINUTES`
- `WHATSAPP_OTP_ALLOW_TEST_OVERRIDE`
- `WHATSAPP_OTP_TEST_PHONE`
- `WHATSAPP_OTP_TEST_CODE`
- `WHATSAPP_OTP_TEST_SCOPE`

## Template contract

The function sends a template message with one body parameter containing the OTP code.
If the template also has a URL button that needs the OTP appended, set
`WHATSAPP_TEMPLATE_URL_BUTTON_INDEX`, for example `0`.

Use a WhatsApp template whose body accepts a single text variable, for example:

`Your DineIn verification code is {{1}}. It expires in 10 minutes.`

## Local development

1. Copy `supabase/.env.example` to `supabase/.env.local`.
2. Fill in the WhatsApp Cloud API values.
3. Run:

```bash
supabase functions serve whatsapp-otp --env-file supabase/.env.local
```

For isolated UI work without Cloud API credentials, set:

```env
WHATSAPP_OTP_ALLOW_MOCK=true
```

The function will then return `debugCode` and mark the challenge as `usesMock=true`.

## Admin console mapping

Admin OTP login looks up `public.dinein_profiles.whatsapp_number`.
Each admin profile must have a unique WhatsApp number before the admin login flow can succeed.

Example update:

```sql
update public.dinein_profiles
set whatsapp_number = '+35699999999'
where role = 'admin' and email = 'admin@example.com';
```

## Closed testing override

For Google Play internal or closed testing, you can allow one explicitly
configured test number to use a fixed OTP code:

- `WHATSAPP_OTP_ALLOW_TEST_OVERRIDE=true`
- `WHATSAPP_OTP_TEST_PHONE=+35699711145`
- `WHATSAPP_OTP_TEST_CODE=123456`
- `WHATSAPP_OTP_TEST_SCOPE=admin`

This should be disabled when testing ends.

## Deployment

Deploy the functions to **both** projects:

```bash
# ── Rwanda (RW) — project ref: kczghhipbyykluuiiunp ──
supabase functions deploy whatsapp-otp --project-ref kczghhipbyykluuiiunp
supabase functions deploy dinein-api   --project-ref kczghhipbyykluuiiunp

# ── Malta (MT) — project ref: uskfnszcdqpcfrhjxitl ──
supabase functions deploy whatsapp-otp --project-ref uskfnszcdqpcfrhjxitl
supabase functions deploy dinein-api   --project-ref uskfnszcdqpcfrhjxitl
```

Apply migrations (link to the target project first):

```bash
# Rwanda
supabase link --project-ref kczghhipbyykluuiiunp
supabase db push --password '...'

# Malta
supabase link --project-ref uskfnszcdqpcfrhjxitl
supabase db push --password '...'
```

Push secrets:

```bash
# Rwanda
supabase secrets set --project-ref kczghhipbyykluuiiunp --env-file supabase/.env.local

# Malta
supabase secrets set --project-ref uskfnszcdqpcfrhjxitl --env-file supabase/.env.local
```

### Country-specific secret differences

| Secret | RW | MT |
|--------|----|----|
| `DEFAULT_WHATSAPP_COUNTRY_CODE` | `250` | `356` |
| `WHATSAPP_TEMPLATE_NAME` | `gikundiro` | *(MT template name)* |
