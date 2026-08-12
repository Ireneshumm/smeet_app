-- Cache for google-places `nearby` results (Explore > Venues).
-- Google bills Nearby Search per request; this table lets the edge function
-- serve repeat browsing of the same ~1km area + category for 72h at no cost.
create table if not exists public.places_nearby_cache (
  cache_key text primary key,
  payload jsonb not null,
  fetched_at timestamptz not null default now()
);

-- Only the edge function (service role) reads/writes this table.
alter table public.places_nearby_cache enable row level security;
-- No policies on purpose: anon/authenticated get no access; service role bypasses RLS.

comment on table public.places_nearby_cache is
  'Server-side cache for Google Places Nearby Search responses (google-places edge function).';
