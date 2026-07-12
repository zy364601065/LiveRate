import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const headers = { "content-type": "application/json" };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });
type Session = "pre_market" | "regular" | "after_hours" | "overnight";
type Quote = { status: "available" | "unavailable"; price?: number; baseline_price?: number; change_amount?: number; change_percent?: number; provider?: string; quote_at?: string; is_stale?: boolean };

function nyParts(date: Date) {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: "America/New_York", weekday: "short", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).formatToParts(date);
  return Object.fromEntries(parts.map((p) => [p.type, p.value]));
}
function currentSession(now = new Date()): Session | "closed" {
  const p = nyParts(now); if (["Sat", "Sun"].includes(p.weekday)) return "closed";
  const m = Number(p.hour) * 60 + Number(p.minute);
  if (m >= 240 && m < 570) return "pre_market";
  if (m >= 570 && m < 960) return "regular";
  if (m >= 960 && m < 1200) return "after_hours";
  return "closed";
}
function bucket(date: Date): Session | null {
  const p = nyParts(date); const m = Number(p.hour) * 60 + Number(p.minute);
  if (m >= 240 && m < 570) return "pre_market";
  if (m >= 570 && m < 960) return "regular";
  if (m >= 960 && m < 1200) return "after_hours";
  return null;
}

async function yahooSessions(symbol: string): Promise<Record<Session, Quote>> {
  const controller = new AbortController(); const timer = setTimeout(() => controller.abort(), 7000);
  try {
    const response = await fetch(`https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1m&range=1d&includePrePost=true`, { signal: controller.signal, headers: { "user-agent": "Mozilla/5.0 LiveRate/1.0" } });
    if (!response.ok) throw new Error(`Yahoo ${response.status}`);
    const result = (await response.json()).chart?.result?.[0]; const meta = result?.meta;
    const previousClose = Number(meta?.chartPreviousClose ?? meta?.previousClose);
    const regularClose = Number(meta?.regularMarketPrice);
    if (!(previousClose > 0)) throw new Error("Yahoo missing previous close");
    const timestamps: number[] = result?.timestamp ?? []; const closes: Array<number | null> = result?.indicators?.quote?.[0]?.close ?? [];
    const latest = new Map<Session, { price: number; timestamp: number }>();
    for (let i = 0; i < timestamps.length; i++) {
      const price = Number(closes[i]); if (!(price > 0)) continue;
      const session = bucket(new Date(timestamps[i] * 1000)); if (session) latest.set(session, { price, timestamp: timestamps[i] });
    }
    const output: Record<Session, Quote> = { pre_market: { status: "unavailable" }, regular: { status: "unavailable" }, after_hours: { status: "unavailable" }, overnight: { status: "unavailable" } };
    for (const session of ["pre_market", "regular", "after_hours"] as Session[]) {
      const point = latest.get(session); if (!point) continue;
      const baseline = session === "after_hours" ? regularClose : previousClose;
      if (!(baseline > 0)) continue; const change = point.price - baseline;
      output[session] = { status: "available", price: point.price, baseline_price: baseline, change_amount: change, change_percent: change / baseline * 100, provider: "Yahoo", quote_at: new Date(point.timestamp * 1000).toISOString(), is_stale: false };
    }
    return output;
  } finally { clearTimeout(timer); }
}

async function finnhubRegular(symbol: string): Promise<Quote> {
  const token = Deno.env.get("FINNHUB_API_KEY"); if (!token) return { status: "unavailable" };
  const response = await fetch(`https://finnhub.io/api/v1/quote?symbol=${encodeURIComponent(symbol)}&token=${encodeURIComponent(token)}`); const q = await response.json();
  if (!(q.c > 0) || !(q.pc > 0)) return { status: "unavailable" }; const change = q.c - q.pc;
  return { status: "available", price: q.c, baseline_price: q.pc, change_amount: change, change_percent: change / q.pc * 100, provider: "Finnhub", quote_at: new Date((q.t || Date.now() / 1000) * 1000).toISOString(), is_stale: false };
}

Deno.serve(async (req) => {
  try {
    const auth = req.headers.get("authorization"); if (!auth) return json({ error: "Unauthorized" }, 401);
    const url = Deno.env.get("SUPABASE_URL")!; const anon = Deno.env.get("SUPABASE_ANON_KEY")!; const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const client = createClient(url, anon, { global: { headers: { Authorization: auth } } }); const { data: { user } } = await client.auth.getUser();
    if (!user) return json({ error: "Unauthorized" }, 401);
    const admin = createClient(url, service); const { data: holdings, error } = await admin.from("user_holdings").select("*").eq("user_id", user.id).is("deleted_at", null); if (error) throw error;
    const symbols = [...new Set((holdings ?? []).map((h) => String(h.stock_code ?? "").trim().toUpperCase()).filter(Boolean))]; const items = [];
    for (const symbol of symbols) {
      let sessions: Record<Session, Quote>;
      try { sessions = await yahooSessions(symbol); } catch { sessions = { pre_market: { status: "unavailable" }, regular: await finnhubRegular(symbol), after_hours: { status: "unavailable" }, overnight: { status: "unavailable" } }; }
      if (sessions.regular.status === "unavailable") sessions.regular = await finnhubRegular(symbol);
      for (const session of ["pre_market", "regular", "after_hours"] as Session[]) {
        const q = sessions[session]; if (q.status !== "available") continue;
        await admin.from("market_quote_cache").upsert({ symbol, session, price: q.price, baseline_price: q.baseline_price, previous_close: session === "after_hours" ? null : q.baseline_price, regular_close: session === "after_hours" ? q.baseline_price : q.price, change_amount: q.change_amount, change_percent: q.change_percent, provider: q.provider, quote_at: q.quote_at, expires_at: new Date(Date.now() + 45000).toISOString(), updated_at: new Date().toISOString() }, { onConflict: "symbol,session" });
      }
      for (const holding of (holdings ?? []).filter((h) => String(h.stock_code ?? "").toUpperCase() === symbol)) {
        const quantity = Number(holding.quantity ?? 0); const update: Record<string, unknown> = { updated_at: new Date().toISOString() };
        for (const session of ["pre_market", "regular", "after_hours"] as Session[]) {
          const q = sessions[session]; if (q.status !== "available") continue;
          update[`${session}_price`] = q.price; update[`${session}_pnl`] = quantity > 0 ? quantity * Number(q.change_amount) : null;
          update[`${session}_pnl_percent`] = q.change_percent; update[`${session}_quote_at`] = q.quote_at; update[`${session}_provider`] = q.provider;
          if (session === "regular") { update.today_pnl = update.regular_pnl; update.today_pnl_percent = q.change_percent; update.regular_close = q.price; update.previous_close = q.baseline_price; }
        }
        const active = sessions[currentSession() as Session]; if (active?.status === "available") { update.current_price = active.price; update.market_value = quantity > 0 ? quantity * Number(active.price) : holding.market_value; update.quote_session = currentSession(); update.quote_at = active.quote_at; update.quote_provider = active.provider; }
        await admin.from("user_holdings").update(update).eq("id", holding.id);
      }
      items.push({ symbol, sessions });
    }
    return json({ session: currentSession(), refreshed_at: new Date().toISOString(), items });
  } catch (error) { return json({ error: error instanceof Error ? error.message : "Quote refresh failed" }, 500); }
});
