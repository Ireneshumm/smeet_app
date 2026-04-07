-- English labels/descriptions for existing rows (if migration 20260330120000 ran with Chinese text).

-- Tennis
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Never played or just starting out'
  WHERE sport = 'Tennis' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'USTA 2.5', level_description = 'Can sustain short rallies, inconsistent serve'
  WHERE sport = 'Tennis' AND level_key = 'usta_2_5';
UPDATE public.sport_level_definitions SET
  level_label = 'USTA 3.0', level_description = 'Consistent rallies, basic technique'
  WHERE sport = 'Tennis' AND level_key = 'usta_3_0';
UPDATE public.sport_level_definitions SET
  level_label = 'USTA 3.5', level_description = 'Can play matches, directional control'
  WHERE sport = 'Tennis' AND level_key = 'usta_3_5';
UPDATE public.sport_level_definitions SET
  level_label = 'USTA 4.0', level_description = 'All-round game, competitive play'
  WHERE sport = 'Tennis' AND level_key = 'usta_4_0';
UPDATE public.sport_level_definitions SET
  level_label = 'USTA 4.5', level_description = 'Heavy topspin, high competitive level'
  WHERE sport = 'Tennis' AND level_key = 'usta_4_5';
UPDATE public.sport_level_definitions SET
  level_label = 'USTA 5.0+', level_description = 'Semi-pro or professional level'
  WHERE sport = 'Tennis' AND level_key = 'usta_5_0';

-- Badminton
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Just starting out'
  WHERE sport = 'Badminton' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Casual', level_description = 'Basic rallies, inconsistent technique'
  WHERE sport = 'Badminton' AND level_key = 'casual';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Singles & doubles, basic tactics'
  WHERE sport = 'Badminton' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'All-round game, amateur competitions'
  WHERE sport = 'Badminton' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'Played in formal tournaments'
  WHERE sport = 'Badminton' AND level_key = 'competitive';
UPDATE public.sport_level_definitions SET
  level_label = 'Elite', level_description = 'Provincial / professional level'
  WHERE sport = 'Badminton' AND level_key = 'elite';

-- Pickleball
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Just starting out'
  WHERE sport = 'Pickleball' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'DUPR 2.0–2.5', level_description = 'Knows basic rules and shots'
  WHERE sport = 'Pickleball' AND level_key = 'dupr_2_0';
UPDATE public.sport_level_definitions SET
  level_label = 'DUPR 3.0–3.5', level_description = 'Consistent shots, understands strategy'
  WHERE sport = 'Pickleball' AND level_key = 'dupr_3_0';
UPDATE public.sport_level_definitions SET
  level_label = 'DUPR 4.0–4.5', level_description = 'Strong 3rd-shot attacks'
  WHERE sport = 'Pickleball' AND level_key = 'dupr_4_0';
UPDATE public.sport_level_definitions SET
  level_label = 'DUPR 5.0+', level_description = 'Competitive / professional level'
  WHERE sport = 'Pickleball' AND level_key = 'dupr_5_0';

-- Golf
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Handicap 36+'
  WHERE sport = 'Golf' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Handicap 28–36', level_description = 'Averaging 5–6 over par per hole'
  WHERE sport = 'Golf' AND level_key = 'handicap_28_36';
UPDATE public.sport_level_definitions SET
  level_label = 'Handicap 18–27', level_description = 'Averaging 3–4 over par per hole'
  WHERE sport = 'Golf' AND level_key = 'handicap_18_27';
UPDATE public.sport_level_definitions SET
  level_label = 'Handicap 10–17', level_description = 'Averaging 1–2 over par per hole'
  WHERE sport = 'Golf' AND level_key = 'handicap_10_17';
UPDATE public.sport_level_definitions SET
  level_label = 'Handicap 0–9', level_description = 'Near scratch level'
  WHERE sport = 'Golf' AND level_key = 'handicap_0_9';
UPDATE public.sport_level_definitions SET
  level_label = 'Scratch & Below', level_description = 'Elite / professional level'
  WHERE sport = 'Golf' AND level_key = 'scratch_plus';

-- Swimming
UPDATE public.sport_level_definitions SET
  level_label = 'Non-swimmer', level_description = 'Cannot swim independently'
  WHERE sport = 'Swimming' AND level_key = 'non_swimmer';
UPDATE public.sport_level_definitions SET
  level_label = 'Can swim 25m', level_description = 'One length of a standard pool'
  WHERE sport = 'Swimming' AND level_key = '25m';
UPDATE public.sport_level_definitions SET
  level_label = 'Can swim 50m', level_description = 'Two lengths of a standard pool'
  WHERE sport = 'Swimming' AND level_key = '50m';
UPDATE public.sport_level_definitions SET
  level_label = 'Can swim 200m', level_description = 'Basic endurance, stable technique'
  WHERE sport = 'Swimming' AND level_key = '200m';
UPDATE public.sport_level_definitions SET
  level_label = 'Can swim 500m+', level_description = 'Endurance training, consistent technique'
  WHERE sport = 'Swimming' AND level_key = '500m_plus';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'Competed in formal swim meets'
  WHERE sport = 'Swimming' AND level_key = 'competitive';

-- Running
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner Runner', level_description = 'Up to 5km, just starting out'
  WHERE sport = 'Running' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = '5km Runner', level_description = 'Pace 7–9 min/km'
  WHERE sport = 'Running' AND level_key = '5km';
UPDATE public.sport_level_definitions SET
  level_label = '10km Runner', level_description = 'Pace 6–7 min/km'
  WHERE sport = 'Running' AND level_key = '10km';
UPDATE public.sport_level_definitions SET
  level_label = 'Half Marathon', level_description = 'Can complete 21km'
  WHERE sport = 'Running' AND level_key = 'half_marathon';
UPDATE public.sport_level_definitions SET
  level_label = 'Full Marathon', level_description = 'Can complete 42km'
  WHERE sport = 'Running' AND level_key = 'marathon';
UPDATE public.sport_level_definitions SET
  level_label = 'Ultra / Competitive', level_description = 'Ultra marathon or competitive runner'
  WHERE sport = 'Running' AND level_key = 'ultra';

-- Ski
UPDATE public.sport_level_definitions SET
  level_label = 'Never Skied', level_description = 'Zero experience'
  WHERE sport = 'Ski' AND level_key = 'never';
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Snowplow turns, green runs'
  WHERE sport = 'Ski' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Blue runs, parallel turns'
  WHERE sport = 'Ski' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Black diamond runs, stable technique'
  WHERE sport = 'Ski' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Expert', level_description = 'Double black diamond, jumps & moguls'
  WHERE sport = 'Ski' AND level_key = 'expert';

-- Snowboard
UPDATE public.sport_level_definitions SET
  level_label = 'Never Snowboarded', level_description = 'Zero experience'
  WHERE sport = 'Snowboard' AND level_key = 'never';
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Basic directional control, can stop'
  WHERE sport = 'Snowboard' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Blue runs, stable turns'
  WHERE sport = 'Snowboard' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Black diamond runs, basic tricks'
  WHERE sport = 'Snowboard' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Expert', level_description = 'Park / competition level'
  WHERE sport = 'Snowboard' AND level_key = 'expert';

-- Basketball
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Just starting out'
  WHERE sport = 'Basketball' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Casual', level_description = 'Pickup games, knows basic rules'
  WHERE sport = 'Basketball' AND level_key = 'casual';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Consistent technique, half/full court'
  WHERE sport = 'Basketball' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Structured training, amateur leagues'
  WHERE sport = 'Basketball' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'School team / club / semi-pro'
  WHERE sport = 'Basketball' AND level_key = 'competitive';

-- Football
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Just starting out'
  WHERE sport = 'Football' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Casual', level_description = 'Pickup games, knows basic rules'
  WHERE sport = 'Football' AND level_key = 'casual';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Consistent technique, positional awareness'
  WHERE sport = 'Football' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Amateur league level'
  WHERE sport = 'Football' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'School team / club level'
  WHERE sport = 'Football' AND level_key = 'competitive';

-- Table Tennis
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Just starting out'
  WHERE sport = 'TableTennis' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Casual', level_description = 'Basic rallies'
  WHERE sport = 'TableTennis' AND level_key = 'casual';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Forehand attack, backhand push'
  WHERE sport = 'TableTennis' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Topspin loops, can compete'
  WHERE sport = 'TableTennis' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'Played in formal tournaments'
  WHERE sport = 'TableTennis' AND level_key = 'competitive';

-- Yoga
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Just started practicing'
  WHERE sport = 'Yoga' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Consistent basic sequences, good flexibility'
  WHERE sport = 'Yoga' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Advanced poses, strong practice'
  WHERE sport = 'Yoga' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Instructor', level_description = 'Certified yoga teacher'
  WHERE sport = 'Yoga' AND level_key = 'instructor';

-- Fitness
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Just started training'
  WHERE sport = 'Fitness' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Training consistently for 6+ months'
  WHERE sport = 'Fitness' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = '2+ years of structured training'
  WHERE sport = 'Fitness' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'Competed in fitness competitions'
  WHERE sport = 'Fitness' AND level_key = 'competitive';

-- Cycling
UPDATE public.sport_level_definitions SET
  level_label = 'Casual Rider', level_description = 'Occasional rides, under 20km'
  WHERE sport = 'Cycling' AND level_key = 'casual';
UPDATE public.sport_level_definitions SET
  level_label = '50km Rider', level_description = 'Can ride 50km, avg 20km/h+'
  WHERE sport = 'Cycling' AND level_key = '50km';
UPDATE public.sport_level_definitions SET
  level_label = '100km Rider', level_description = 'Century rides, avg 25km/h+'
  WHERE sport = 'Cycling' AND level_key = '100km';
UPDATE public.sport_level_definitions SET
  level_label = 'Gran Fondo', level_description = '160km+ rides, hill experience'
  WHERE sport = 'Cycling' AND level_key = 'gran_fondo';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'Road racing / hill climb events'
  WHERE sport = 'Cycling' AND level_key = 'competitive';

-- Climbing
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Indoor bouldering V0–V2'
  WHERE sport = 'Climbing' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Indoor bouldering V3–V5'
  WHERE sport = 'Climbing' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Indoor V6–V8, outdoor experience'
  WHERE sport = 'Climbing' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Expert', level_description = 'V9+, outdoor multipitch routes'
  WHERE sport = 'Climbing' AND level_key = 'expert';

-- Volleyball
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Just starting out'
  WHERE sport = 'Volleyball' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Casual', level_description = 'Basic passing and serving'
  WHERE sport = 'Volleyball' AND level_key = 'casual';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Consistent technique, positional play'
  WHERE sport = 'Volleyball' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Amateur league level'
  WHERE sport = 'Volleyball' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'School team / club level'
  WHERE sport = 'Volleyball' AND level_key = 'competitive';

-- Squash
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Just starting out'
  WHERE sport = 'Squash' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Casual', level_description = 'Basic rallies'
  WHERE sport = 'Squash' AND level_key = 'casual';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Consistent technique'
  WHERE sport = 'Squash' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Can compete at club level'
  WHERE sport = 'Squash' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'Club / competitive level'
  WHERE sport = 'Squash' AND level_key = 'competitive';

-- Baseball / softball (not in user SQL Editor block; keep in sync with seed migration)
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Just starting out with baseball / softball'
  WHERE sport = 'Baseball' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Casual', level_description = 'Basic throwing and hitting'
  WHERE sport = 'Baseball' AND level_key = 'casual';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Knows rules, can play games'
  WHERE sport = 'Baseball' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Strong all-round, amateur league'
  WHERE sport = 'Baseball' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'Club / competitive level'
  WHERE sport = 'Baseball' AND level_key = 'competitive';

-- Rugby
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'Just starting out'
  WHERE sport = 'Rugby' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Casual', level_description = 'Knows basic rules and passing'
  WHERE sport = 'Rugby' AND level_key = 'casual';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Can play amateur matches'
  WHERE sport = 'Rugby' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Strong fitness and technique'
  WHERE sport = 'Rugby' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'Club / school team level'
  WHERE sport = 'Rugby' AND level_key = 'competitive';

-- Hockey
UPDATE public.sport_level_definitions SET
  level_label = 'Beginner', level_description = 'New to hockey'
  WHERE sport = 'Hockey' AND level_key = 'beginner';
UPDATE public.sport_level_definitions SET
  level_label = 'Casual', level_description = 'Can skate and control the puck'
  WHERE sport = 'Hockey' AND level_key = 'casual';
UPDATE public.sport_level_definitions SET
  level_label = 'Intermediate', level_description = 'Can play pickup games'
  WHERE sport = 'Hockey' AND level_key = 'intermediate';
UPDATE public.sport_level_definitions SET
  level_label = 'Advanced', level_description = 'Strong all-round game'
  WHERE sport = 'Hockey' AND level_key = 'advanced';
UPDATE public.sport_level_definitions SET
  level_label = 'Competitive', level_description = 'Club / league level'
  WHERE sport = 'Hockey' AND level_key = 'competitive';
