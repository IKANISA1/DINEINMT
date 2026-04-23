// Compatibility facade for the legacy dinein-api entrypoint.
//
// The split edge functions already use ../_shared/core-monolith.ts as the
// working source of truth. Re-exporting it here keeps the existing handler and
// test import paths stable while avoiding drift between two copies.
export * from "../_shared/core-monolith.ts";
