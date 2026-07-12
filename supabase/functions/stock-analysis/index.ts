import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const authorization = request.headers.get("Authorization") ?? "";
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: authorization } } });
    const { data: { user }, error } = await supabase.auth.getUser();
    if (error || !user) return json({ error: "请先登录" }, 401);
    const body = await request.json();
    const symbol = String(body.symbol ?? "").trim().toUpperCase();
    if (!/^[A-Z0-9.\-]{1,16}$/.test(symbol)) return json({ error: "股票代码格式不正确" }, 400);
    const aiURL = (Deno.env.get("AI_SERVICE_URL") ?? "").replace(/\/$/, "");
    if (!aiURL) return json({ error: "AI 分析服务尚未配置" }, 503);
    const token = Deno.env.get("AI_SERVICE_TOKEN")?.trim();
    if (!token) return json({ error: "AI 服务鉴权 Token 尚未配置" }, 503);
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    headers.Authorization = `Bearer ${token}`;
    const upstream = await fetch(`${aiURL}/api/v1/analysis/analyze`, {
      method: "POST", headers,
      body: JSON.stringify({ stock_code: symbol, stock_name: String(body.name ?? "").trim() || null, report_type: "detailed", force_refresh: false, async_mode: false, analysis_phase: "auto", selection_source: "import", notify: false, report_language: "zh", skills: ["bull_trend", "growth_quality"] })
    });
    const payload = await upstream.json().catch(() => ({}));
    if (!upstream.ok) return json({ error: payload.detail ?? payload.message ?? payload.error ?? "AI 分析失败" }, upstream.status);
    return json({ symbol, name: payload.stock_name ?? body.name ?? null, content: typeof payload.report === "string" ? payload.report : JSON.stringify(payload.report ?? {}, null, 2), created_at: payload.created_at ?? new Date().toISOString() });
  } catch (error) { return json({ error: error instanceof Error ? error.message : "AI 分析失败" }, 500); }
});

function json(value: unknown, status = 200) { return new Response(JSON.stringify(value), { status, headers: { ...cors, "Content-Type": "application/json" } }); }
