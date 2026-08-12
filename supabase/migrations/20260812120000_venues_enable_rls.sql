-- Fix Supabase security advisory: public.venues had RLS disabled, so anyone
-- with the project URL could read/modify/delete every row via the anon key.
--
-- The app only ever READS venues (Explore > Venues tab, guests included), so:
--   - keep public read access (anon + authenticated)
--   - no insert/update/delete policies -> writes only via service role/dashboard
alter table public.venues enable row level security;

drop policy if exists "venues_public_read" on public.venues;
create policy "venues_public_read"
  on public.venues
  for select
  to anon, authenticated
  using (true);
