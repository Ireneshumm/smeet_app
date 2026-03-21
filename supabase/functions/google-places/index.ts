/**
 * Proxies Google Places Autocomplete + Place Details (Deno / Supabase Edge).
 * Key: `Deno.env.get("GOOGLE_MAPS_API_KEY")` — set via `supabase secrets set` (never commit keys).
 *
 * POST JSON (include unused fields as null/omit as needed):
 *   - action: "autocomplete" | "details"
 *   - input: string (required for autocomplete)
 *   - placeId: string (required for details)
 *   - sessionToken: string (optional, billing session token)
 *
 * Responses:
 *   - autocomplete → same JSON as Google Autocomplete API
 *   - details → { address, latitude, longitude }
 */

const GOOGLE_AUTOCOMPLETE =
  "https://maps.googleapis.com/maps/api/place/autocomplete/json";
const GOOGLE_DETAILS =
  "https://maps.googleapis.com/maps/api/place/details/json";

function json(
  body: unknown,
  status: number,
  cors: Record<string, string>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...cors,
      "Content-Type": "application/json",
    },
  });
}

/** Strip trailing slashes so https://a.com matches https://a.com/ */
function normalizeOrigin(o: string): string {
  return o.replace(/\/+$/, "");
}

/**
 * True when `requestOrigin` matches an entry in `allowedList` (after normalize).
 * `http://localhost` also allows `http://localhost:8080` etc. Same for `127.0.0.1`.
 */
function isOriginAllowed(requestOrigin: string, allowedList: string[]): boolean {
  const o = normalizeOrigin(requestOrigin);
  for (const raw of allowedList) {
    const entry = normalizeOrigin(raw);
    if (o === entry) return true;

    try {
      const u = new URL(o);
      if (
        entry === "http://localhost" &&
        u.protocol === "http:" &&
        u.hostname === "localhost"
      ) {
        return true;
      }
      if (
        entry === "https://localhost" &&
        u.protocol === "https:" &&
        u.hostname === "localhost"
      ) {
        return true;
      }
      if (
        entry === "http://127.0.0.1" &&
        u.protocol === "http:" &&
        u.hostname === "127.0.0.1"
      ) {
        return true;
      }
      if (
        entry === "https://127.0.0.1" &&
        u.protocol === "https:" &&
        u.hostname === "127.0.0.1"
      ) {
        return true;
      }
    } catch {
      // ignore
    }
  }
  return false;
}

/**
 * CORS for Flutter Web + mobile.
 * - If `PLACES_ALLOWED_ORIGINS` is unset/empty → `Access-Control-Allow-Origin: *`
 * - If set (comma-separated) → reflect the request `Origin` only when it matches the list
 * - No `Origin` header (some native clients) → allow with `*` so invoke still works
 */
function corsHeaders(req: Request): {
  ok: boolean;
  headers: Record<string, string>;
} {
  const base: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };

  const raw = Deno.env.get("PLACES_ALLOWED_ORIGINS")?.trim();
  if (!raw) {
    return {
      ok: true,
      headers: { ...base, "Access-Control-Allow-Origin": "*" },
    };
  }

  const allowed = raw.split(",").map((s) => s.trim()).filter(Boolean);
  const origin = req.headers.get("Origin");

  if (!origin) {
    return {
      ok: true,
      headers: { ...base, "Access-Control-Allow-Origin": "*" },
    };
  }

  if (isOriginAllowed(origin, allowed)) {
    const reflected = normalizeOrigin(origin);
    return {
      ok: true,
      headers: { ...base, "Access-Control-Allow-Origin": reflected },
    };
  }

  console.warn(
    `google-places CORS: Origin not allowed: ${origin}, allowed list: ${allowed.join(", ")}`,
  );
  return { ok: false, headers: base };
}

Deno.serve(async (req: Request) => {
  const { ok, headers: ch } = corsHeaders(req);

  if (req.method === "OPTIONS") {
    if (!ok) {
      return new Response(null, { status: 403, headers: ch });
    }
    return new Response(null, { status: 204, headers: ch });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405, ch);
  }

  if (!ok) {
    return json({ error: "Origin not allowed" }, 403, ch);
  }

  const apiKey =
    Deno.env.get("GOOGLE_MAPS_API_KEY")?.trim() ??
    Deno.env.get("Maps_API_KEY")?.trim();
  if (!apiKey) {
    console.error(
      "google-places: set secret GOOGLE_MAPS_API_KEY or Maps_API_KEY",
    );
    return json({ error: "Places search is not configured" }, 500, ch);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400, ch);
  }

  const action = String(payload.action ?? "");
  const sessionToken = String(payload.sessionToken ?? "");

  if (action === "autocomplete") {
    const input = String(payload.input ?? "").trim();
    if (!input) {
      return json({ error: "input is required" }, 400, ch);
    }

    const url = new URL(GOOGLE_AUTOCOMPLETE);
    url.searchParams.set("input", input);
    url.searchParams.set("key", apiKey);
    if (sessionToken) url.searchParams.set("sessiontoken", sessionToken);

    const res = await fetch(url.toString());
    const data = await res.json();
    return new Response(JSON.stringify(data), {
      status: res.ok ? 200 : res.status,
      headers: { ...ch, "Content-Type": "application/json" },
    });
  }

  if (action === "details") {
    const placeId = String(payload.placeId ?? "").trim();
    if (!placeId) {
      return json({ error: "placeId is required" }, 400, ch);
    }

    const url = new URL(GOOGLE_DETAILS);
    url.searchParams.set("place_id", placeId);
    url.searchParams.set("fields", "formatted_address,geometry");
    url.searchParams.set("key", apiKey);
    if (sessionToken) url.searchParams.set("sessiontoken", sessionToken);

    const res = await fetch(url.toString());
    const data = (await res.json()) as Record<string, unknown>;
    const status = String(data.status ?? "");

    if (!res.ok || status !== "OK") {
      const err = String(data.error_message ?? "Place details failed");
      return json({ error: err, status }, res.ok ? 400 : res.status, ch);
    }

    const result = data.result as Record<string, unknown> | undefined;
    const geometry = result?.geometry as Record<string, unknown> | undefined;
    const location = geometry?.location as Record<string, unknown> | undefined;
    const lat = (location?.lat as number | undefined) ??
      (location?.lat as string | undefined);
    const lng = (location?.lng as number | undefined) ??
      (location?.lng as string | undefined);
    const address = String(result?.formatted_address ?? "").trim();

    const latitude = typeof lat === "number"
      ? lat
      : lat != null
      ? Number(lat)
      : NaN;
    const longitude = typeof lng === "number"
      ? lng
      : lng != null
      ? Number(lng)
      : NaN;

    if (!address || Number.isNaN(latitude) || Number.isNaN(longitude)) {
      return json({ error: "Invalid place details payload" }, 502, ch);
    }

    return json(
      {
        address,
        latitude,
        longitude,
      },
      200,
      ch,
    );
  }

  return json({ error: "Unknown action" }, 400, ch);
});
