-- Migration: Add Promos to dinein_venues

ALTER TABLE "public"."dinein_venues"
ADD COLUMN "promo_message" TEXT,
ADD COLUMN "is_promo_active" BOOLEAN NOT NULL DEFAULT false;

-- Add a comment describing the columns
COMMENT ON COLUMN "public"."dinein_venues"."promo_message" IS 'Highlights a special promo or announcement on the guest PWA home screen.';
COMMENT ON COLUMN "public"."dinein_venues"."is_promo_active" IS 'Toggles whether the promo_message should currently be visible to guests.';
