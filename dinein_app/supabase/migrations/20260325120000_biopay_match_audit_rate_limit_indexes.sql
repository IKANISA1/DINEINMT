-- Support durable BioPay match throttling by indexing the audit fields
-- queried by the edge function rate limiter.

begin;

create index if not exists idx_biopay_match_audit_client_install_created_at
  on public.biopay_match_audit (client_install_id, created_at desc)
  where client_install_id is not null;

create index if not exists idx_biopay_match_audit_ip_hash_created_at
  on public.biopay_match_audit (ip_hash, created_at desc)
  where ip_hash is not null;

commit;
