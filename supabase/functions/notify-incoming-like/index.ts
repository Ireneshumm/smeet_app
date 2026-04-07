import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!;

serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record;

    if (record?.type !== "incoming_like") {
      return new Response("skip", { status: 200 });
    }

    const userId = record.user_id as string;
    const actorId = record.actor_user_id as string | null | undefined;
    if (!userId || !actorId) {
      return new Response("skip", { status: 200 });
    }

    const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    const { data: existing } = await db
      .from("push_notification_log")
      .select("id")
      .eq("user_id", userId)
      .eq("type", "incoming_like")
      .eq("ref_id", actorId)
      .gte("sent_at", new Date(Date.now() - 86400000).toISOString())
      .maybeSingle();

    if (existing) return new Response("dedup", { status: 200 });

    const { data: actorProfile } = await db
      .from("profiles")
      .select("display_name")
      .eq("id", actorId)
      .maybeSingle();

    const actorName = actorProfile?.display_name ?? "有人";

    const { data: tokens } = await db
      .from("user_push_tokens")
      .select("fcm_token")
      .eq("user_id", userId);

    if (!tokens || tokens.length === 0) {
      return new Response("no tokens", { status: 200 });
    }

    for (const row of tokens) {
      const fcm_token = row.fcm_token as string;
      await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `key=${FCM_SERVER_KEY}`,
        },
        body: JSON.stringify({
          to: fcm_token,
          notification: {
            title: "有人想跟你打球 🎾",
            body: `${actorName} 喜欢了你 — 去看看是谁`,
            sound: "default",
          },
          data: {
            type: "incoming_like",
            actor_id: String(actorId),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        }),
      });
    }

    await db.from("push_notification_log").insert({
      user_id: userId,
      type: "incoming_like",
      ref_id: actorId,
    });

    return new Response("ok", { status: 200 });
  } catch (e) {
    return new Response(String(e), { status: 500 });
  }
});
