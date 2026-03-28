-- Allow authenticated users to delete their own post rows (DB only; storage cleanup is separate).
-- Prerequisite: `public.posts` already has RLS enabled and existing policies for SELECT/INSERT
-- (do not enable RLS here without those policies or reads/writes will be blocked).

drop policy if exists "posts_delete_own" on public.posts;

create policy "posts_delete_own"
  on public.posts
  for delete
  to authenticated
  using (author_id = auth.uid());
