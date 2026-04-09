CREATE UNIQUE INDEX IF NOT EXISTS uq_dinein_venues_owner_whatsapp_number_active
  ON public.dinein_venues (owner_whatsapp_number)
  WHERE owner_whatsapp_number IS NOT NULL
    AND NULLIF(BTRIM(owner_whatsapp_number), '') IS NOT NULL
    AND status <> 'deleted';
