/**
 * AI features (Deno / Supabase Edge): "AI find players" and "AI chat coach".
 *
 * Secrets (never commit keys):
 *   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
 *   supabase secrets set AI_MODEL=claude-haiku-5-5        # optional
 *
 * Deploy:
 *   supabase functions deploy ai-assistant
 *
 * Auth: requires a signed-in user (verify_jwt = true). All database reads use
 * the caller's JWT, so RLS applies exactly as it does in the app — the
 * function can only see profiles the user could already browse.
 *
 * POST JSON:
 *   - action: "find_players"
 *       query: string                         (what the user is looking for)
 *       near?: { lat, lng, label?, radiusKm? } (picked location; optional)
 *     → { summary, results: [{ id, display_name, avatar_url, city,
 *          sport_levels, distance_km, reason }] }
 *
 *   - action: "chat_coach"
 *       mode: "opener" | "reply" | "polish"
 *       otherUserId: string
 *       messages?: [{ from: "me" | "them", text }]   (last few, reply mode)
 *       draft?: string                               (polish mode)
 *     → { suggestions: string[], tip: string }
 *
 * Nothing is stored: requests are processed and discarded.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const MODEL = Deno.env.get("AI_MODEL") ?? "claude-haiku-5-5";

const MAX_QUERY_CHARS = 400;
const MAX_MESSAGES = 10;
const MAX_MESSAGE_CHARS = 500;
const CANDIDATE_POOL = 300;
const RANK_POOL = 40;
const MAX_RESULTS = 8;
const DEFAULT_RADIUS_KM = 30;

const PROFILE_COLUMNS =
  "id, display_name, city, intro, avatar_url, sport_levels, availability, location_lat, location_lng";

/** Supabase client acting as the caller (their JWT, so RLS applies). */
function clientFor(authHeader: string) {
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
}
type Db = ReturnType<typeof clientFor>;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// Claude

const TONE_RULES = `Smeet is a premium social app where people meet through
tennis, golf, skiing and scuba diving. It is NOT a dating app.
- Be warm, respectful and natural. Focus on shared sport, plans and genuine interest.
- Never write pickup lines, flirting tactics, pressure, guilt-tripping or manipulation.
- Never guess or mention sensitive traits (age, looks, religion, ethnicity, health, orientation).
- Only use facts given to you; never invent details about anyone.`;

type Tool = { name: string; description: string; input_schema: unknown };

/** Calls Claude with a single forced tool and returns that tool's input. */
async function callTool<T>(
  system: string,
  user: string,
  tool: Tool,
  maxTokens = 800,
): Promise<T> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: maxTokens,
      system,
      tools: [tool],
      tool_choice: { type: "tool", name: tool.name },
      messages: [{ role: "user", content: user }],
    }),
  });
  if (!res.ok) {
    throw new Error(`anthropic ${res.status}: ${await res.text()}`);
  }
  const data = await res.json();
  const block = (data.content ?? []).find(
    (b: { type: string }) => b.type === "tool_use",
  );
  if (!block) throw new Error("anthropic: no tool_use block");
  return block.input as T;
}

// ---------------------------------------------------------------------------
// Helpers

type Profile = {
  id: string;
  display_name: string | null;
  city: string | null;
  intro: string | null;
  avatar_url: string | null;
  sport_levels: Record<string, unknown> | null;
  availability: unknown;
  location_lat: number | null;
  location_lng: number | null;
};

function clip(s: unknown, n: number): string {
  const t = (s ?? "").toString().trim();
  return t.length > n ? t.slice(0, n) + "…" : t;
}

function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(a));
}

function sportsOf(p: Profile): string[] {
  return p.sport_levels && typeof p.sport_levels === "object"
    ? Object.keys(p.sport_levels)
    : [];
}

function isComplete(p: Profile): boolean {
  const city = (p.city ?? "").trim();
  return (p.display_name ?? "").trim().length >= 2 &&
    (p.avatar_url ?? "").trim().length > 0 &&
    city.length > 0 && !city.toLowerCase().includes("not set");
}

/** Compact, non-identifying card sent to the model for ranking. */
function profileCard(p: Profile, distanceKm: number | null) {
  return {
    id: p.id,
    city: clip(p.city, 60),
    sports: p.sport_levels ?? {},
    availability: p.availability ?? null,
    intro: clip(p.intro, 240),
    distance_km: distanceKm == null ? null : Math.round(distanceKm),
  };
}

// ---------------------------------------------------------------------------
// find_players

type Criteria = {
  sports: string[];
  city: string | null;
  near_me: boolean;
  radius_km: number | null;
  summary: string;
};

const PARSE_TOOL: Tool = {
  name: "search_criteria",
  description: "Structured criteria extracted from the user's request.",
  input_schema: {
    type: "object",
    properties: {
      sports: {
        type: "array",
        items: { type: "string", enum: ["Tennis", "Golf", "Ski", "Diving"] },
        description: "Sports mentioned. Empty if none.",
      },
      city: {
        type: ["string", "null"],
        description: "City or suburb mentioned, else null.",
      },
      near_me: {
        type: "boolean",
        description: "True if the user asks for people near them / nearby.",
      },
      radius_km: { type: ["number", "null"] },
      summary: {
        type: "string",
        description:
          "One short line restating what they want, in the user's language.",
      },
    },
    required: ["sports", "city", "near_me", "radius_km", "summary"],
  },
};

const RANK_TOOL: Tool = {
  name: "ranked_players",
  description: "Best-matching candidates, best first.",
  input_schema: {
    type: "object",
    properties: {
      matches: {
        type: "array",
        maxItems: MAX_RESULTS,
        items: {
          type: "object",
          properties: {
            id: { type: "string" },
            reason: {
              type: "string",
              description:
                "One short sentence, in the user's language, citing only facts from the candidate card.",
            },
          },
          required: ["id", "reason"],
        },
      },
    },
    required: ["matches"],
  },
};

async function findPlayers(
  db: Db,
  me: Profile | null,
  uid: string,
  body: Record<string, unknown>,
) {
  const query = clip(body.query, MAX_QUERY_CHARS);
  if (!query) return json({ error: "empty_query" }, 400);

  const criteria = await callTool<Criteria>(
    `${TONE_RULES}\nExtract search criteria for finding sport partners.`,
    query,
    PARSE_TOOL,
    300,
  );

  // Where to search from: a picked location wins, then "near me".
  const near = body.near as
    | { lat?: number; lng?: number; label?: string; radiusKm?: number }
    | undefined;
  let origin: { lat: number; lng: number } | null = null;
  if (typeof near?.lat === "number" && typeof near?.lng === "number") {
    origin = { lat: near.lat, lng: near.lng };
  } else if (
    criteria.near_me && me?.location_lat != null && me?.location_lng != null
  ) {
    origin = { lat: me.location_lat, lng: me.location_lng };
  }
  const radiusKm = Number(
    near?.radiusKm ?? criteria.radius_km ?? DEFAULT_RADIUS_KM,
  );

  let q = db.from("profiles").select(PROFILE_COLUMNS).neq("id", uid);
  if (!origin && criteria.city) {
    q = q.ilike("city", `%${criteria.city.replace(/[%_,()]/g, "")}%`);
  }
  const { data, error } = await q.limit(CANDIDATE_POOL);
  if (error) throw new Error(`profiles: ${error.message}`);

  const wanted = new Set(criteria.sports.map((s) => s.toLowerCase()));
  const pool = ((data ?? []) as Profile[])
    .filter(isComplete)
    .filter((p) =>
      wanted.size === 0 ||
      sportsOf(p).some((s) => wanted.has(s.toLowerCase()))
    )
    .map((p) => {
      const d = origin && p.location_lat != null && p.location_lng != null
        ? haversineKm(origin.lat, origin.lng, p.location_lat, p.location_lng)
        : null;
      return { p, d };
    })
    .filter(({ d }) => !origin || (d != null && d <= radiusKm))
    .sort((a, b) => (a.d ?? Infinity) - (b.d ?? Infinity))
    .slice(0, RANK_POOL);

  const summary = near?.label
    ? `${criteria.summary} · ${clip(near.label, 80)}`
    : criteria.summary;
  if (pool.length === 0) return json({ summary, results: [] });

  const ranked = await callTool<{ matches: { id: string; reason: string }[] }>(
    `${TONE_RULES}
Pick the candidates who best fit the request. Consider sport, level,
availability, location and intro. Skip anyone who clearly does not fit.
Return at most ${MAX_RESULTS}.`,
    JSON.stringify({
      request: query,
      searcher: me
        ? { city: clip(me.city, 60), sports: me.sport_levels ?? {} }
        : null,
      candidates: pool.map(({ p, d }) => profileCard(p, d)),
    }),
    RANK_TOOL,
    1200,
  );

  const byId = new Map(pool.map((e) => [e.p.id, e]));
  const results = ranked.matches
    .filter((m) => byId.has(m.id))
    .slice(0, MAX_RESULTS)
    .map((m) => {
      const { p, d } = byId.get(m.id)!;
      return {
        id: p.id,
        display_name: p.display_name,
        avatar_url: p.avatar_url,
        city: p.city,
        sport_levels: p.sport_levels,
        distance_km: d == null ? null : Math.round(d * 10) / 10,
        reason: clip(m.reason, 200),
      };
    });
  return json({ summary, results });
}

// ---------------------------------------------------------------------------
// chat_coach

const COACH_TOOL: Tool = {
  name: "chat_suggestions",
  description: "Suggested messages the user may send, plus one coaching tip.",
  input_schema: {
    type: "object",
    properties: {
      suggestions: {
        type: "array",
        minItems: 1,
        maxItems: 3,
        items: { type: "string" },
        description: "Ready-to-send messages, each under 200 characters.",
      },
      tip: {
        type: "string",
        description:
          "One short sentence explaining why these work, so the user learns.",
      },
    },
    required: ["suggestions", "tip"],
  },
};

const COACH_TASK: Record<string, string> = {
  opener:
    "They have not chatted yet. Suggest 3 different friendly openers that reference something real they share (sport, city, intro).",
  reply:
    "Suggest 3 natural next messages for 'me' that keep the conversation going — ask open questions, respond to what 'them' said, or suggest a concrete game.",
  polish:
    "Rewrite the user's draft to sound friendlier and more natural. Keep their meaning and language. Give up to 3 variants.",
};

async function chatCoach(
  db: Db,
  me: Profile | null,
  body: Record<string, unknown>,
) {
  const mode = String(body.mode ?? "");
  const task = COACH_TASK[mode];
  const otherId = String(body.otherUserId ?? "");
  if (!task || !otherId) return json({ error: "bad_request" }, 400);

  const { data: other } = await db
    .from("profiles")
    .select(PROFILE_COLUMNS)
    .eq("id", otherId)
    .maybeSingle();

  const messages = Array.isArray(body.messages)
    ? (body.messages as { from?: string; text?: string }[])
      .slice(-MAX_MESSAGES)
      .map((m) => ({
        from: m.from === "me" ? "me" : "them",
        text: clip(m.text, MAX_MESSAGE_CHARS),
      }))
      .filter((m) => m.text)
    : [];
  const draft = clip(body.draft, MAX_MESSAGE_CHARS);
  if (mode === "polish" && !draft) return json({ error: "empty_draft" }, 400);

  const card = (p: Profile | null) =>
    p
      ? {
        first_name: clip(p.display_name, 40).split(/\s+/)[0],
        city: clip(p.city, 60),
        sports: p.sport_levels ?? {},
        intro: clip(p.intro, 240),
      }
      : null;

  const out = await callTool<{ suggestions: string[]; tip: string }>(
    `${TONE_RULES}
You are a friendly chat coach. ${task}
Write in the same language the conversation uses (default English).
Keep suggestions short, specific and easy to send.`,
    JSON.stringify({
      me: card(me),
      them: card(other as Profile | null),
      recent_messages: messages,
      draft: mode === "polish" ? draft : undefined,
    }),
    COACH_TOOL,
    600,
  );
  return json({
    suggestions: (out.suggestions ?? []).slice(0, 3).map((s) => clip(s, 300)),
    tip: clip(out.tip, 240),
  });
}

// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!ANTHROPIC_API_KEY) return json({ error: "ai_not_configured" }, 503);

  const authHeader = req.headers.get("Authorization") ?? "";
  const db = clientFor(authHeader);
  const { data: auth } = await db.auth.getUser(
    authHeader.replace(/^Bearer\s+/i, ""),
  );
  const uid = auth?.user?.id;
  if (!uid) return json({ error: "unauthorized" }, 401);

  try {
    const body = await req.json() as Record<string, unknown>;
    const { data: me } = await db
      .from("profiles")
      .select(PROFILE_COLUMNS)
      .eq("id", uid)
      .maybeSingle();

    switch (body.action) {
      case "find_players":
        return await findPlayers(db, me as Profile | null, uid, body);
      case "chat_coach":
        return await chatCoach(db, me as Profile | null, body);
      default:
        return json({ error: "unknown_action" }, 400);
    }
  } catch (e) {
    console.error("ai-assistant failed:", e);
    return json({ error: "ai_failed" }, 502);
  }
});
