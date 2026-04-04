# Google Play Store Listing — DineIn

## Malta (com.dineinmalta.app)

### App Details

| Field             | Content                                                              |
| ----------------- | -------------------------------------------------------------------- |
| **App Name**      | DineIn Malta                                                         |
| **Short Desc**    | Scan a QR code, browse the menu, and order from your table in Malta. |
| **Developer**     | IKANISA                                                              |
| **Category**      | Food & Drink                                                         |
| **Content Rating**| Everyone (PEGI 3)                                                    |
| **Contact Email** | info@ikanisa.com                                                     |
| **Privacy Policy**| https://dineinmt.ikanisa.com/privacy.html                            |

### Full Description (max 4000 chars)

```
DineIn Malta is the smart way to order at any partner restaurant in Malta.

HOW IT WORKS
1. Scan the QR code on your table
2. Browse the full menu on your phone
3. Add items and place your order in just 4 taps
4. Sit back — your food is on its way

FEATURES
• Instant menus — No app download needed to browse. QR scan opens your table menu instantly.
• Fast ordering — Add items to your cart and order in seconds. No waving at waiters.
• Real-time tracking — Know when your order is received, being prepared, and served.
• Discover venues — Browse and explore restaurants across Malta.
• Pay your way — Cash, card, or Revolut. No in-app payment processing.
• Venue Wi-Fi — Auto-connect to the venue's Wi-Fi network with one tap.
• Order history — View past orders and reorder your favourites.
• Zero fees — No service fees, no markups. You pay menu prices only.

FOR VENUE OWNERS
• Manage your menu and orders from a dedicated venue portal
• Receive instant push notifications for new orders and table service requests
• Generate table QR codes for your restaurant
• AI-powered menu setup — upload a photo of your paper menu and we extract it for you

DineIn Malta is free for guests. No account required to browse and order.

Download now and discover Malta's best restaurants from your table.
```

### Assets Checklist

| Asset               | Spec            | Status               | Path                             |
| -------------------- | --------------- | -------------------- | -------------------------------- |
| App Icon             | 512×512 PNG     | ✅ (via Flutter)     | `android/app/src/main/res/`      |
| Feature Graphic      | 1024×500 PNG    | ❌ **NEEDS CREATION** | `store_assets/feature_graphic.png` |
| Phone Screenshots    | min 2, 320–3840 | ✅ 8 assets          | `store_assets/android/phone/`    |
| Tablet 7" Screenshots | min 2          | ⚠️ Dir exists        | `store_assets/android/tablet_7/` |
| Tablet 10" Screenshots | min 2         | ⚠️ Dir exists        | `store_assets/android/tablet_10/`|

### Missing Assets — Action Items
1. **Feature Graphic** (1024×500) — Must be created. No text overlays per Google policy.
2. **Tablet screenshots** — Verify content exists in tablet directories.

---

## Rwanda (com.dineinrw.app)

### App Details

| Field             | Content                                                               |
| ----------------- | --------------------------------------------------------------------- |
| **App Name**      | DineIn Rwanda                                                         |
| **Short Desc**    | Scan a QR code, browse the menu, and order from your table in Rwanda. |
| **Developer**     | IKANISA                                                               |
| **Category**      | Food & Drink                                                          |
| **Content Rating**| Everyone (PEGI 3)                                                     |
| **Contact Email** | info@ikanisa.com                                                      |
| **Privacy Policy**| https://dineinrw.ikanisa.com/privacy.html                             |

### Full Description

Same structure as Malta, with "Rwanda" replacing "Malta" and "MoMo" replacing "Revolut".

---

## Pre-Submission Checklist

- [ ] Feature graphic created (1024×500)
- [ ] Tablet screenshots verified
- [ ] Data Safety form completed (see DATA_SAFETY.md)
- [ ] IARC rating questionnaire completed (see DATA_SAFETY.md §5)
- [ ] Internal Testing track set up with 20+ testers
- [ ] 14-day testing period completed
- [ ] Privacy policy URL accessible and up to date
- [ ] Account deletion mechanism implemented and tested
- [ ] All app permissions are justified in store listing
