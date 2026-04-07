import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!;

async function sendFcm(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `key=${FCM_SERVER_KEY}`,
    },
    body: JSON.stringify({
      to: token,
      notification: { title, body, sound: "default" },
      data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
    }),
  });
}

serve(async () => {
  const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const now = new Date();

  const window2hStart = new Date(now.getTime() + 90 * 60 * 1000);
  const window2hEnd = new Date(now.getTime() + 150 * 60 * 1000);

  const { data: upcomingGames } = await db
    .from("games")
    .select("id, sport, location_text, starts_at")
    .gte("starts_at", window2hStart.toISOString())
    .lte("starts_at", window2hEnd.toISOString())
    .eq("reminder_2h_sent", false);

  for (const game of upcomingGames ?? []) {
    const { data: participants } = await db
      .from("game_participants")
      .select("user_id")
      .eq("game_id", game.id)
      .eq("status", "joined");

    const sport = (game.sport as string | null) ?? "球";
    const loc = ((game.location_text as string | null) ?? "").split(",")[0]
      .trim();

    for (const p of participants ?? []) {
      const user_id = p.user_id as string;
      const { data: tokens } = await db
        .from("user_push_tokens")
        .select("fcm_token")
        .eq("user_id", user_id);

      for (const t of tokens ?? []) {
        await sendFcm(
          t.fcm_token as string,
          `你的${sport}局还有 2h 开球 ⚡️`,
          loc ? `📍 ${loc}` : "准备好了吗？",
          { type: "game_reminder", game_id: String(game.id) },
        );
      }
    }

    await db.from("games")
      .update({ reminder_2h_sent: true })
      .eq("id", game.id);
  }

  const window30mStart = new Date(now.getTime() - 60 * 60 * 1000);
  const window30mEnd = new Date(now.getTime() - 20 * 60 * 1000);

  const { data: endedGames } = await db
    .from("games")
    .select("id, sport")
    .gte("ends_at", window30mStart.toISOString())
    .lte("ends_at", window30mEnd.toISOString())
    .eq("battle_report_reminder_sent", false);

  for (const game of endedGames ?? []) {
    const { data: participants } = await db
      .from("game_participants")
      .select("user_id")
      .eq("game_id", game.id)
      .eq("status", "joined");

    const sport = (game.sport as string | null) ?? "球";

    for (const p of participants ?? []) {
      const user_id = p.user_id as string;
      const { data: tokens } = await db
        .from("user_push_tokens")
        .select("fcm_token")
        .eq("user_id", user_id);

      for (const t of tokens ?? []) {
        await sendFcm(
          t.fcm_token as string,
          `刚打完${sport}？发个战报 🏆`,
          "让球友看看你今天的表现",
          { type: "battle_report_reminder", game_id: String(game.id) },
        );
      }
    }

    await db.from("games")
      .update({ battle_report_reminder_sent: true })
      .eq("id", game.id);
  }

  return new Response("ok", { status: 200 });
});
