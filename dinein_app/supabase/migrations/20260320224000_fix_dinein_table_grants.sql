-- Restore table grants expected by the mobile backend and Edge Functions.

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

GRANT ALL ON TABLE
  public.dinein_profiles,
  public.dinein_venues,
  public.dinein_venue_claims,
  public.dinein_menu_items,
  public.dinein_orders
TO service_role;

GRANT SELECT ON TABLE
  public.dinein_venues,
  public.dinein_menu_items
TO anon;

GRANT INSERT ON TABLE
  public.dinein_venue_claims,
  public.dinein_orders
TO anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.dinein_profiles,
  public.dinein_venues,
  public.dinein_venue_claims,
  public.dinein_menu_items,
  public.dinein_orders
TO authenticated;
