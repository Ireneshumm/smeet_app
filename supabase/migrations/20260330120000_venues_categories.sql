-- Venues: extended categories + extra fields + sample rows.
-- Run after `venues` exists (create minimal table if missing).

CREATE TABLE IF NOT EXISTS public.venues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category text NOT NULL DEFAULT 'sports_court',
  description text,
  address text,
  location_lat double precision,
  location_lng double precision,
  cover_image_url text,
  booking_url text,
  website_url text,
  phone text,
  sport text[],
  sports text[],
  tags text[],
  is_featured boolean NOT NULL DEFAULT false,
  is_verified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.venues ADD COLUMN IF NOT EXISTS sport text[];
ALTER TABLE public.venues ADD COLUMN IF NOT EXISTS sports text[];
ALTER TABLE public.venues ADD COLUMN IF NOT EXISTS tags text[];

-- Legacy category values → new keys
UPDATE public.venues SET category = 'sports_court' WHERE category = 'sports';
UPDATE public.venues SET category = 'retail' WHERE category = 'store';

ALTER TABLE public.venues
  ADD COLUMN IF NOT EXISTS opening_hours text,
  ADD COLUMN IF NOT EXISTS instagram_url text,
  ADD COLUMN IF NOT EXISTS images text[],
  ADD COLUMN IF NOT EXISTS price_range text,
  ADD COLUMN IF NOT EXISTS rating numeric(3,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS review_count int NOT NULL DEFAULT 0;

INSERT INTO public.venues (
  name,
  category,
  description,
  address,
  location_lat,
  location_lng,
  booking_url,
  website_url,
  sport,
  tags,
  is_featured,
  is_verified,
  price_range
)
VALUES
  (
    'F45 Training Brisbane City',
    'gym',
    'High-intensity functional training. 45-minute team workouts that get results.',
    'Brisbane City, QLD',
    -27.4698,
    153.0251,
    'https://f45training.com.au',
    'https://f45training.com.au',
    ARRAY['Fitness', 'CrossFit'],
    ARRAY['Fitness', 'Brisbane', 'HIIT', 'Group Training'],
    false,
    false,
    '$$'
  ),
  (
    'Brisbane Aquatic Centre',
    'pool',
    'Olympic-size swimming pool. Lane swimming, squads, and casual sessions available.',
    'Chandler, Brisbane QLD',
    -27.5436,
    153.1214,
    'https://brisbane.qld.gov.au',
    null,
    ARRAY['Swimming'],
    ARRAY['Swimming', 'Brisbane', 'Olympic Pool'],
    false,
    false,
    '$'
  ),
  (
    'Revive Sports Massage',
    'massage',
    'Sports massage and recovery therapy for active people. Deep tissue, remedial, and post-event recovery.',
    'New Farm, Brisbane QLD',
    -27.4710,
    153.0520,
    null,
    null,
    null,
    ARRAY['Recovery', 'Sports Massage', 'Brisbane'],
    false,
    false,
    '$$'
  ),
  (
    'Active Physio Brisbane',
    'physio',
    'Sports physiotherapy, injury rehabilitation, and performance optimization for athletes.',
    'South Brisbane, QLD',
    -27.4820,
    153.0180,
    null,
    null,
    null,
    ARRAY['Physiotherapy', 'Rehabilitation', 'Brisbane'],
    false,
    false,
    '$$'
  ),
  (
    'Nutrition Warehouse Brisbane',
    'nutrition',
    'Sports nutrition, supplements, and health products. Expert advice from certified nutritionists.',
    'Brisbane CBD, QLD',
    -27.4698,
    153.0251,
    'https://nutritionwarehouse.com.au',
    'https://nutritionwarehouse.com.au',
    null,
    ARRAY['Nutrition', 'Supplements', 'Brisbane'],
    false,
    false,
    '$'
  ),
  (
    'Lululemon Brisbane',
    'apparel',
    'Premium athletic apparel for yoga, running, training, and everything in between.',
    'Queen Street Mall, Brisbane QLD',
    -27.4698,
    153.0235,
    'https://lululemon.com.au',
    'https://lululemon.com.au',
    null,
    ARRAY['Apparel', 'Yoga', 'Running', 'Brisbane'],
    false,
    false,
    '$$$'
  ),
  (
    'Rebel Sport Brisbane',
    'equipment',
    'Australia''s largest sports retailer. Everything you need for every sport.',
    'Brisbane CBD, QLD',
    -27.4698,
    153.0251,
    'https://rebelsport.com.au',
    'https://rebelsport.com.au',
    null,
    ARRAY['Equipment', 'Multi-sport', 'Brisbane'],
    false,
    false,
    '$$'
  );
