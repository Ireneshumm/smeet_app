-- FCM tokens (client upsert); push log (Edge Functions + service role); game reminder flags.

create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  fcm_token text not null,
  platform text not null,
  updated_at timestamptz default now(),
  unique (user_id, fcm_token)
);

alter table public.user_push_tokens enable row level security;

drop policy if exists "own tokens" on public.user_push_tokens;
create policy "own tokens" on public.user_push_tokens
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.push_notification_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  type text not null,
  ref_id text,
  sent_at timestamptz default now(),
  unique (user_id, type, ref_id)
);

alter table public.push_notification_log enable row level security;

alter table public.games
  add column if not exists reminder_2h_sent boolean default false;

alter table public.games
  add column if not exists battle_report_reminder_sent boolean default false;
