-- Optional poster URL for video posts (feed thumbnail); generated client-side on upload.
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS cover_image_url text;
