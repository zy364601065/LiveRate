import express from "express";
import multer from "multer";
import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

type MoodScope = "global" | "user";
type MoodBehavior = "random" | "manual";
type AssetKind = "default" | "profit" | "loss";

type ModeRow = {
  id: string;
  user_id: string | null;
  scope: MoodScope;
  name: string;
  behavior: MoodBehavior;
  selected_profit_asset_id: string | null;
  selected_loss_asset_id: string | null;
  created_at: string;
};

type AssetRow = {
  id: string;
  mode_id: string;
  user_id: string | null;
  kind: AssetKind;
  sort_order: number;
  storage_path: string;
  created_at: string;
};

type ModePayload = ModeRow & {
  assets: Array<AssetRow & { signed_url: string | null }>;
};

type FullscreenAnimationRow = {
  id: string;
  scope: MoodScope;
  user_id: string | null;
  name: string;
  trigger_type: FullscreenAnimationTriggerType;
  storage_path: string;
  content_type: string;
  file_type: "lottie";
  is_enabled: boolean;
  created_at: string;
  updated_at: string;
};

type FullscreenAnimationPayload = FullscreenAnimationRow & {
  signed_url: string | null;
};

type FullscreenAnimationTriggerType = "max_profit_day" | "birthday_home";
type ExtremeDayTriggerType = "consecutive_loss" | "consecutive_profit" | "loss_to_profit" | "profit_to_loss";

type ExtremeDayMessageRow = {
  id: string;
  scope: MoodScope;
  user_id: string | null;
  trigger_type: ExtremeDayTriggerType;
  message: string;
  is_enabled: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
};

type ProfileRow = {
  id: string;
  nickname: string;
  birthday: string | null;
  created_at: string;
  updated_at: string;
};

type StatUploadRecordRow = {
  id: string;
  user_id: string;
  timestamp: string;
  usd_amount: number;
};

type StatUploadRecordPayload = StatUploadRecordRow & {
  nickname: string | null;
};

type HoldingRow = {
  id: string; user_id: string; source_key: string; stock_name: string; stock_code: string | null;
  market_value: number | null; quantity: number | null; current_price: number | null; cost_price: number | null;
  today_pnl: number | null; today_pnl_percent: number | null; holding_pnl: number | null;
  holding_pnl_percent: number | null; data_timestamp: string; created_at: string; updated_at: string; deleted_at: string | null;
};

type AdminUserPayload = {
  id: string;
  email: string | null;
  nickname: string | null;
  birthday: string | null;
  created_at: string | null;
  last_sign_in_at: string | null;
  is_anonymous: boolean;
  profile_status: "synced" | "missing";
  stats_record_count?: number;
  private_mood_count?: number;
  holding_count?: number;
};

type AuthUserRow = {
  id: string;
  email?: string | null;
  created_at?: string | null;
  last_sign_in_at?: string | null;
  is_anonymous?: boolean | null;
};

loadLocalEnv();

const supabaseUrl = requireEnv("SUPABASE_URL");
const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
const adminPassword = requireEnv("ADMIN_PASSWORD");
const port = Number(process.env.PORT ?? 5174);
const bucketName = "stats-mood-gifs";
const fullscreenAnimationBucketName = "stats-fullscreen-animations";

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
});

const app = express();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    files: 1,
    fileSize: 15 * 1024 * 1024
  }
});

app.use(express.json({ limit: "1mb" }));

app.get("/api/health", (_request, response) => {
  response.json({ ok: true });
});

app.post("/api/login", (request, response) => {
  const password = String(request.body?.password ?? "");
  if (password !== adminPassword) {
    response.status(401).json({ error: "密码不正确" });
    return;
  }

  response.json({ ok: true });
});

app.use("/api", (request, response, next) => {
  if (request.path === "/login" || request.path === "/health") {
    next();
    return;
  }

  if (request.header("x-admin-password") !== adminPassword) {
    response.status(401).json({ error: "请先登录后台" });
    return;
  }

  next();
});

app.get("/api/modes", async (_request, response) => {
  try {
    response.json({ modes: await fetchModes() });
  } catch (error) {
    sendError(response, error);
  }
});

app.get("/api/fullscreen-animations", async (_request, response) => {
  try {
    response.json({ animations: await fetchFullscreenAnimations() });
  } catch (error) {
    sendError(response, error);
  }
});

app.get("/api/trend-messages", async (_request, response) => {
  try {
    response.json({ messages: await fetchExtremeDayMessages() });
  } catch (error) {
    sendError(response, error);
  }
});

app.get("/api/users", async (request, response) => {
  try {
    const search = String(request.query.search ?? "").trim().toLowerCase();
    const users = await fetchUsers();
    const filteredUsers = search
      ? users.filter((user) =>
          user.id.toLowerCase().includes(search)
          || (user.email ?? "").toLowerCase().includes(search)
          || (user.nickname ?? "").toLowerCase().includes(search)
        )
      : users;

    response.json({ users: filteredUsers });
  } catch (error) {
    sendError(response, error);
  }
});

app.get("/api/users/:userID", async (request, response) => {
  try {
    const userID = requireUUID(String(request.params.userID), "用户 ID");
    const users = await fetchUsers();
    const user = users.find((item) => item.id === userID);
    if (!user) throw new HttpError(404, "用户不存在");

    response.json({ user: await enrichUserDetail(user) });
  } catch (error) {
    sendError(response, error);
  }
});

app.patch("/api/users/:userID/profile", async (request, response) => {
  try {
    const userID = requireUUID(String(request.params.userID), "用户 ID");
    const users = await fetchUsers();
    const user = users.find((item) => item.id === userID);
    if (!user) throw new HttpError(404, "用户不存在");

    const profile: Omit<ProfileRow, "created_at" | "updated_at"> = {
      id: userID,
      nickname: validateNickname(request.body?.nickname ?? user.nickname ?? makeDefaultNickname()),
      birthday: validateBirthday(request.body?.birthday)
    };

    const { error } = await supabase
      .from("user_profiles")
      .upsert(profile, { onConflict: "id" });

    if (error) throw error;

    const refreshedUsers = await fetchUsers();
    const refreshedUser = refreshedUsers.find((item) => item.id === userID);
    if (!refreshedUser) throw new HttpError(404, "用户不存在");

    response.json({ user: await enrichUserDetail(refreshedUser) });
  } catch (error) {
    sendError(response, error);
  }
});

app.get("/api/users/:userID/holdings", async (request, response) => {
  try {
    const userID = requireUUID(String(request.params.userID), "用户 ID");
    const { data, error } = await supabase.from("user_holdings").select("*")
      .eq("user_id", userID).is("deleted_at", null).order("data_timestamp", { ascending: false });
    if (error) throw error;
    response.json({ holdings: (data ?? []) as HoldingRow[] });
  } catch (error) { sendError(response, error); }
});

app.patch("/api/users/:userID/holdings/:holdingID", async (request, response) => {
  try {
    const userID = requireUUID(String(request.params.userID), "用户 ID");
    const holdingID = requireUUID(String(request.params.holdingID), "持仓 ID");
    const stockName = String(request.body?.stock_name ?? "").trim();
    if (!stockName || stockName.length > 160) throw new HttpError(400, "股票名称不能为空且不能超过 160 字");
    const nullableNumber = (name: string): number | null => {
      const value = request.body?.[name];
      if (value === null || value === undefined || value === "") return null;
      const number = Number(value);
      if (!Number.isFinite(number)) throw new HttpError(400, `${name} 必须是有效数字`);
      return number;
    };
    const patch = {
      stock_name: stockName,
      stock_code: String(request.body?.stock_code ?? "").trim() || null,
      market_value: nullableNumber("market_value"), quantity: nullableNumber("quantity"),
      current_price: nullableNumber("current_price"), cost_price: nullableNumber("cost_price"),
      today_pnl: nullableNumber("today_pnl"), today_pnl_percent: nullableNumber("today_pnl_percent"),
      holding_pnl: nullableNumber("holding_pnl"), holding_pnl_percent: nullableNumber("holding_pnl_percent"),
      updated_at: new Date().toISOString()
    };
    const { data, error } = await supabase.from("user_holdings").update(patch).eq("id", holdingID)
      .eq("user_id", userID).is("deleted_at", null).select("*").maybeSingle();
    if (error) throw error;
    if (!data) throw new HttpError(404, "持仓不存在");
    response.json({ holding: data as HoldingRow });
  } catch (error) { sendError(response, error); }
});

app.delete("/api/users/:userID/holdings/:holdingID", async (request, response) => {
  try {
    const userID = requireUUID(String(request.params.userID), "用户 ID");
    const holdingID = requireUUID(String(request.params.holdingID), "持仓 ID");
    const now = new Date().toISOString();
    const { data, error } = await supabase.from("user_holdings").update({ deleted_at: now, updated_at: now })
      .eq("id", holdingID).eq("user_id", userID).is("deleted_at", null).select("id").maybeSingle();
    if (error) throw error;
    if (!data) throw new HttpError(404, "持仓不存在");
    response.status(204).end();
  } catch (error) { sendError(response, error); }
});

app.get("/api/stat-upload-records", async (_request, response) => {
  try {
    response.json({ records: await fetchStatUploadRecords() });
  } catch (error) {
    sendError(response, error);
  }
});

app.post("/api/fullscreen-animations", upload.single("file"), async (request, response) => {
  try {
    const name = validateFullscreenAnimationName(request.body?.name);
    const scope = validateScope(request.body?.scope);
    const userId = validateUserID(scope, request.body?.userId);
    const triggerType = validateFullscreenAnimationTriggerType(request.body?.triggerType);
    const file = requireLottieFile(request.file);
    const animationID = randomUUID();
    const storagePath = buildFullscreenAnimationStoragePath(scope, userId, animationID);

    const { error: uploadError } = await supabase.storage
      .from(fullscreenAnimationBucketName)
      .upload(storagePath, file.buffer, {
        contentType: "application/zip",
        cacheControl: "604800",
        upsert: false
      });

    if (uploadError) throw uploadError;

    const animation: Omit<FullscreenAnimationRow, "created_at" | "updated_at"> = {
      id: animationID,
      scope,
      user_id: userId,
      name,
      trigger_type: triggerType,
      storage_path: storagePath,
      content_type: "application/zip",
      file_type: "lottie",
      is_enabled: true
    };

    const { error: insertError } = await supabase
      .from("stats_fullscreen_animations")
      .insert(animation);

    if (insertError) {
      await removeFullscreenAnimationStorageObjects([storagePath]).catch(() => undefined);
      throw insertError;
    }

    response.status(201).json({ animations: await fetchFullscreenAnimations() });
  } catch (error) {
    sendError(response, error);
  }
});

app.patch("/api/fullscreen-animations/:animationID", async (request, response) => {
  try {
    const animationID = requireUUID(String(request.params.animationID), "动画 ID");
    const patch: Record<string, string | boolean | null> = {
      updated_at: new Date().toISOString()
    };

    if (request.body?.name !== undefined) {
      patch.name = validateFullscreenAnimationName(request.body.name);
    }

    if (request.body?.triggerType !== undefined) {
      patch.trigger_type = validateFullscreenAnimationTriggerType(request.body.triggerType);
    }

    if (request.body?.scope !== undefined) {
      const scope = validateScope(request.body.scope);
      patch.scope = scope;
      patch.user_id = validateUserID(scope, request.body?.userId);
      const animation = await fetchFullscreenAnimation(animationID);
      patch.storage_path = buildFullscreenAnimationStoragePath(scope, patch.user_id as string | null, animationID);

      if (animation.storage_path !== patch.storage_path) {
        await moveFullscreenAnimationStorageObject(animation.storage_path, patch.storage_path as string);
      }
    }

    if (request.body?.isEnabled !== undefined) {
      patch.is_enabled = Boolean(request.body.isEnabled);
    }

    const { error } = await supabase
      .from("stats_fullscreen_animations")
      .update(patch)
      .eq("id", animationID);

    if (error) throw error;
    response.json({ animations: await fetchFullscreenAnimations() });
  } catch (error) {
    sendError(response, error);
  }
});

app.post("/api/fullscreen-animations/:animationID/replace", upload.single("file"), async (request, response) => {
  try {
    const animationID = requireUUID(String(request.params.animationID), "动画 ID");
    const file = requireLottieFile(request.file);
    const animation = await fetchFullscreenAnimation(animationID);

    const { error } = await supabase.storage
      .from(fullscreenAnimationBucketName)
      .update(animation.storage_path, file.buffer, {
        contentType: "application/zip",
        cacheControl: "604800",
        upsert: true
      });

    if (error) throw error;

    const { error: updateError } = await supabase
      .from("stats_fullscreen_animations")
      .update({ updated_at: new Date().toISOString() })
      .eq("id", animationID);

    if (updateError) throw updateError;
    response.json({ animations: await fetchFullscreenAnimations() });
  } catch (error) {
    sendError(response, error);
  }
});

app.delete("/api/fullscreen-animations/:animationID", async (request, response) => {
  try {
    const animationID = requireUUID(String(request.params.animationID), "动画 ID");
    const animation = await fetchFullscreenAnimation(animationID);
    await removeFullscreenAnimationStorageObjects([animation.storage_path]);

    const { error } = await supabase
      .from("stats_fullscreen_animations")
      .delete()
      .eq("id", animationID);

    if (error) throw error;
    response.json({ animations: await fetchFullscreenAnimations() });
  } catch (error) {
    sendError(response, error);
  }
});

app.post("/api/trend-messages", async (request, response) => {
  try {
    const scope = validateScope(request.body?.scope);
    const userId = validateUserID(scope, request.body?.userId);
    const message: Omit<ExtremeDayMessageRow, "created_at" | "updated_at"> = {
      id: randomUUID(),
      scope,
      user_id: userId,
      trigger_type: validateExtremeDayTriggerType(request.body?.triggerType),
      message: validateExtremeDayMessage(request.body?.message),
      is_enabled: true,
      sort_order: Number.isFinite(Number(request.body?.sortOrder)) ? Number(request.body.sortOrder) : 0
    };

    const { error } = await supabase
      .from("stats_trend_messages")
      .insert(message);

    if (error) throw error;
    response.status(201).json({ messages: await fetchExtremeDayMessages() });
  } catch (error) {
    sendError(response, error);
  }
});

app.patch("/api/trend-messages/:messageID", async (request, response) => {
  try {
    const messageID = requireUUID(String(request.params.messageID), "文案 ID");
    const patch: Record<string, string | number | boolean | null> = {
      updated_at: new Date().toISOString()
    };

    if (request.body?.scope !== undefined) {
      const scope = validateScope(request.body.scope);
      patch.scope = scope;
      patch.user_id = validateUserID(scope, request.body?.userId);
    }

    if (request.body?.triggerType !== undefined) {
      patch.trigger_type = validateExtremeDayTriggerType(request.body.triggerType);
    }

    if (request.body?.message !== undefined) {
      patch.message = validateExtremeDayMessage(request.body.message);
    }

    if (request.body?.isEnabled !== undefined) {
      patch.is_enabled = Boolean(request.body.isEnabled);
    }

    if (request.body?.sortOrder !== undefined) {
      patch.sort_order = validateSortOrder(request.body.sortOrder);
    }

    const { error } = await supabase
      .from("stats_trend_messages")
      .update(patch)
      .eq("id", messageID);

    if (error) throw error;
    response.json({ messages: await fetchExtremeDayMessages() });
  } catch (error) {
    sendError(response, error);
  }
});

app.delete("/api/trend-messages/:messageID", async (request, response) => {
  try {
    const messageID = requireUUID(String(request.params.messageID), "文案 ID");
    const { error } = await supabase
      .from("stats_trend_messages")
      .delete()
      .eq("id", messageID);

    if (error) throw error;
    response.json({ messages: await fetchExtremeDayMessages() });
  } catch (error) {
    sendError(response, error);
  }
});

app.post("/api/modes", async (request, response) => {
  try {
    const name = validateName(request.body?.name);
    const scope = validateScope(request.body?.scope);
    const userId = validateUserID(scope, request.body?.userId);
    const behavior = validateBehavior(request.body?.behavior ?? "random");

    const mode: Omit<ModeRow, "created_at"> = {
      id: randomUUID(),
      user_id: userId,
      scope,
      name,
      behavior,
      selected_profit_asset_id: null,
      selected_loss_asset_id: null
    };

    const { error } = await supabase
      .from("stats_mood_modes")
      .insert(mode);

    if (error) throw error;
    response.status(201).json({ mode: (await fetchModes()).find((item) => item.id === mode.id) });
  } catch (error) {
    sendError(response, error);
  }
});

app.patch("/api/modes/:modeID", async (request, response) => {
  try {
    const modeID = requireUUID(String(request.params.modeID), "模式 ID");
    const patch: Record<string, string | null> = {};

    if (request.body?.name !== undefined) {
      patch.name = validateName(request.body.name);
    }

    if (request.body?.behavior !== undefined) {
      patch.behavior = validateBehavior(request.body.behavior);
    }

    if (request.body?.scope !== undefined) {
      const scope = validateScope(request.body.scope);
      patch.scope = scope;
      patch.user_id = validateUserID(scope, request.body?.userId);
    }

    const { error } = await supabase
      .from("stats_mood_modes")
      .update({ ...patch, updated_at: new Date().toISOString() })
      .eq("id", modeID);

    if (error) throw error;
    response.json({ mode: (await fetchModes()).find((item) => item.id === modeID) });
  } catch (error) {
    sendError(response, error);
  }
});

app.delete("/api/modes/:modeID", async (request, response) => {
  try {
    const modeID = requireUUID(String(request.params.modeID), "模式 ID");
    const assets = await fetchAssetsForMode(modeID);

    await removeStorageObjects(assets.map((asset) => asset.storage_path));

    const { error } = await supabase
      .from("stats_mood_modes")
      .delete()
      .eq("id", modeID);

    if (error) throw error;
    response.json({ ok: true });
  } catch (error) {
    sendError(response, error);
  }
});

app.post("/api/modes/:modeID/assets", upload.single("file"), async (request, response) => {
  try {
    const modeID = requireUUID(String(request.params.modeID), "模式 ID");
    const kind = validateKind(request.body?.kind);
    const file = requireGIFFile(request.file);
    const mode = await fetchMode(modeID);
    const existingAssets = await fetchAssetsForMode(modeID);
    const existingForKind = existingAssets.filter((asset) => asset.kind === kind);

    if (kind !== "default" && existingForKind.length >= 5) {
      throw new HttpError(400, "盈利/亏损 GIF 最多 5 张");
    }

    if (kind === "default" && existingForKind.length > 0) {
      await deleteAssetRows(existingForKind);
    }

    const assetID = randomUUID();
    const sortOrder = kind === "default" ? 0 : nextSortOrder(existingForKind);
    const storagePath = buildStoragePath(mode, assetID);

    const { error: uploadError } = await supabase.storage
      .from(bucketName)
      .upload(storagePath, file.buffer, {
        contentType: "image/gif",
        cacheControl: "604800",
        upsert: false
      });

    if (uploadError) throw uploadError;

    const asset: Omit<AssetRow, "created_at"> = {
      id: assetID,
      mode_id: modeID,
      user_id: mode.user_id,
      kind,
      sort_order: sortOrder,
      storage_path: storagePath
    };

    const { error: insertError } = await supabase
      .from("stats_mood_assets")
      .insert(asset);

    if (insertError) throw insertError;

    if (kind === "profit" && !mode.selected_profit_asset_id) {
      await setSelectedAsset(modeID, "profit", assetID);
    }

    if (kind === "loss" && !mode.selected_loss_asset_id) {
      await setSelectedAsset(modeID, "loss", assetID);
    }

    response.status(201).json({ modes: await fetchModes() });
  } catch (error) {
    sendError(response, error);
  }
});

app.post("/api/assets/:assetID/replace", upload.single("file"), async (request, response) => {
  try {
    const assetID = requireUUID(String(request.params.assetID), "资源 ID");
    const file = requireGIFFile(request.file);
    const asset = await fetchAsset(assetID);

    const { error } = await supabase.storage
      .from(bucketName)
      .update(asset.storage_path, file.buffer, {
        contentType: "image/gif",
        cacheControl: "604800",
        upsert: true
      });

    if (error) throw error;
    response.json({ modes: await fetchModes() });
  } catch (error) {
    sendError(response, error);
  }
});

app.patch("/api/assets/:assetID/select", async (request, response) => {
  try {
    const assetID = requireUUID(String(request.params.assetID), "资源 ID");
    const asset = await fetchAsset(assetID);

    if (asset.kind !== "profit" && asset.kind !== "loss") {
      throw new HttpError(400, "默认表情不能设为手动盈利/亏损选择");
    }

    await setSelectedAsset(asset.mode_id, asset.kind, asset.id);
    response.json({ modes: await fetchModes() });
  } catch (error) {
    sendError(response, error);
  }
});

app.delete("/api/assets/:assetID", async (request, response) => {
  try {
    const assetID = requireUUID(String(request.params.assetID), "资源 ID");
    const asset = await fetchAsset(assetID);
    await deleteAssetRows([asset]);
    response.json({ modes: await fetchModes() });
  } catch (error) {
    sendError(response, error);
  }
});

app.listen(port, "127.0.0.1", () => {
  console.log(`ZhongAn Assistant admin API running at http://127.0.0.1:${port}`);
});

async function fetchModes(): Promise<ModePayload[]> {
  const { data: modes, error: modesError } = await supabase
    .from("stats_mood_modes")
    .select("*")
    .order("created_at", { ascending: false });

  if (modesError) throw modesError;

  const { data: assets, error: assetsError } = await supabase
    .from("stats_mood_assets")
    .select("*")
    .order("sort_order", { ascending: true });

  if (assetsError) throw assetsError;

  const signedByPath = new Map<string, string | null>();
  for (const asset of (assets ?? []) as AssetRow[]) {
    if (signedByPath.has(asset.storage_path)) continue;
    const { data } = await supabase.storage
      .from(bucketName)
      .createSignedUrl(asset.storage_path, 60 * 60 * 24 * 7);
    signedByPath.set(asset.storage_path, data?.signedUrl ?? null);
  }

  const assetsByMode = new Map<string, Array<AssetRow & { signed_url: string | null }>>();
  for (const asset of (assets ?? []) as AssetRow[]) {
    const group = assetsByMode.get(asset.mode_id) ?? [];
    group.push({ ...asset, signed_url: signedByPath.get(asset.storage_path) ?? null });
    assetsByMode.set(asset.mode_id, group);
  }

  return ((modes ?? []) as ModeRow[]).map((mode) => ({
    ...mode,
    assets: assetsByMode.get(mode.id) ?? []
  }));
}

async function fetchFullscreenAnimations(): Promise<FullscreenAnimationPayload[]> {
  const { data: animations, error } = await supabase
    .from("stats_fullscreen_animations")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) throw error;

  const typedAnimations = (animations ?? []) as FullscreenAnimationRow[];
  const signedByPath = new Map<string, string | null>();

  for (const animation of typedAnimations) {
    if (signedByPath.has(animation.storage_path)) continue;
    const { data } = await supabase.storage
      .from(fullscreenAnimationBucketName)
      .createSignedUrl(animation.storage_path, 60 * 60 * 24 * 7);
    signedByPath.set(animation.storage_path, data?.signedUrl ?? null);
  }

  return typedAnimations.map((animation) => ({
    ...animation,
    signed_url: signedByPath.get(animation.storage_path) ?? null
  }));
}

async function fetchExtremeDayMessages(): Promise<ExtremeDayMessageRow[]> {
  const { data, error } = await supabase
    .from("stats_trend_messages")
    .select("*")
    .order("trigger_type", { ascending: true })
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: false });

  if (error) throw error;
  return (data ?? []) as ExtremeDayMessageRow[];
}

async function fetchUsers(): Promise<AdminUserPayload[]> {
  const users: AuthUserRow[] = [];
  let page = 1;
  const perPage = 100;

  while (true) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage });
    if (error) throw error;
    users.push(...data.users);
    if (!data.nextPage || data.users.length === 0) break;
    page = data.nextPage;
  }

  const { data: profiles, error: profilesError } = await supabase
    .from("user_profiles")
    .select("*");

  if (profilesError) throw profilesError;

  const typedProfiles = (profiles ?? []) as ProfileRow[];
  const profileByID = new Map(typedProfiles.map((profile) => [profile.id, profile]));

  return users.map((user) => {
    const profile = profileByID.get(user.id);
    return {
      id: user.id,
      email: user.email ?? null,
      nickname: profile?.nickname ?? null,
      birthday: profile?.birthday ?? null,
      created_at: user.created_at ?? null,
      last_sign_in_at: user.last_sign_in_at ?? null,
      is_anonymous: user.is_anonymous ?? false,
      profile_status: profile ? "synced" : "missing"
    };
  });
}

async function enrichUserDetail(user: AdminUserPayload): Promise<AdminUserPayload> {
  const { count: statsRecordCount, error: statsError } = await supabase
    .from("stat_upload_records")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id);

  if (statsError) throw statsError;

  const { count: privateMoodCount, error: moodError } = await supabase
    .from("stats_mood_modes")
    .select("id", { count: "exact", head: true })
    .eq("scope", "user")
    .eq("user_id", user.id);

  if (moodError) throw moodError;

  const { count: holdingCount, error: holdingError } = await supabase.from("user_holdings")
    .select("id", { count: "exact", head: true }).eq("user_id", user.id).is("deleted_at", null);
  if (holdingError) throw holdingError;

  return {
    ...user,
    stats_record_count: statsRecordCount ?? 0,
    private_mood_count: privateMoodCount ?? 0,
    holding_count: holdingCount ?? 0
  };
}

async function fetchStatUploadRecords(): Promise<StatUploadRecordPayload[]> {
  const { data: records, error: recordsError } = await supabase
    .from("stat_upload_records")
    .select("id,user_id,timestamp,usd_amount")
    .order("timestamp", { ascending: false })
    .limit(500);

  if (recordsError) throw recordsError;

  const typedRecords = (records ?? []) as StatUploadRecordRow[];
  const userIDs = Array.from(new Set(typedRecords.map((record) => record.user_id)));
  const profileByID = new Map<string, ProfileRow>();

  if (userIDs.length > 0) {
    const { data: profiles, error: profilesError } = await supabase
      .from("user_profiles")
      .select("id,nickname,birthday,created_at,updated_at")
      .in("id", userIDs);

    if (profilesError) throw profilesError;

    for (const profile of (profiles ?? []) as ProfileRow[]) {
      profileByID.set(profile.id, profile);
    }
  }

  return typedRecords.map((record) => ({
    ...record,
    nickname: profileByID.get(record.user_id)?.nickname ?? null
  }));
}

async function fetchMode(modeID: string): Promise<ModeRow> {
  const { data, error } = await supabase
    .from("stats_mood_modes")
    .select("*")
    .eq("id", modeID)
    .single();

  if (error) throw error;
  return data as ModeRow;
}

async function fetchAsset(assetID: string): Promise<AssetRow> {
  const { data, error } = await supabase
    .from("stats_mood_assets")
    .select("*")
    .eq("id", assetID)
    .single();

  if (error) throw error;
  return data as AssetRow;
}

async function fetchFullscreenAnimation(animationID: string): Promise<FullscreenAnimationRow> {
  const { data, error } = await supabase
    .from("stats_fullscreen_animations")
    .select("*")
    .eq("id", animationID)
    .single();

  if (error) throw error;
  return data as FullscreenAnimationRow;
}

async function fetchAssetsForMode(modeID: string): Promise<AssetRow[]> {
  const { data, error } = await supabase
    .from("stats_mood_assets")
    .select("*")
    .eq("mode_id", modeID)
    .order("sort_order", { ascending: true });

  if (error) throw error;
  return (data ?? []) as AssetRow[];
}

async function deleteAssetRows(assets: AssetRow[]): Promise<void> {
  await removeStorageObjects(assets.map((asset) => asset.storage_path));

  const ids = assets.map((asset) => asset.id);
  if (ids.length === 0) return;

  const { error } = await supabase
    .from("stats_mood_assets")
    .delete()
    .in("id", ids);

  if (error) throw error;
}

async function removeStorageObjects(paths: string[]): Promise<void> {
  if (paths.length === 0) return;
  const { error } = await supabase.storage
    .from(bucketName)
    .remove(paths);
  if (error) throw error;
}

async function removeFullscreenAnimationStorageObjects(paths: string[]): Promise<void> {
  if (paths.length === 0) return;
  const { error } = await supabase.storage
    .from(fullscreenAnimationBucketName)
    .remove(paths);
  if (error) throw error;
}

async function moveFullscreenAnimationStorageObject(fromPath: string, toPath: string): Promise<void> {
  if (fromPath === toPath) return;
  const { error } = await supabase.storage
    .from(fullscreenAnimationBucketName)
    .move(fromPath, toPath);
  if (error) throw error;
}

async function setSelectedAsset(modeID: string, kind: "profit" | "loss", assetID: string): Promise<void> {
  const patch = kind === "profit"
    ? { selected_profit_asset_id: assetID, updated_at: new Date().toISOString() }
    : { selected_loss_asset_id: assetID, updated_at: new Date().toISOString() };

  const { error } = await supabase
    .from("stats_mood_modes")
    .update(patch)
    .eq("id", modeID);

  if (error) throw error;
}

function buildStoragePath(mode: ModeRow, assetID: string): string {
  const owner = mode.scope === "global" ? "global" : mode.user_id;
  if (!owner) throw new HttpError(400, "指定用户模式缺少用户 ID");
  return `${owner}/${mode.id}/${assetID}.gif`;
}

function buildFullscreenAnimationStoragePath(scope: MoodScope, userID: string | null, animationID: string): string {
  const owner = scope === "global" ? "global" : userID;
  if (!owner) throw new HttpError(400, "指定用户动画缺少用户 ID");
  return `${owner}/${animationID}.lottie`;
}

function nextSortOrder(assets: AssetRow[]): number {
  const used = new Set(assets.map((asset) => asset.sort_order));
  for (let index = 0; index < 5; index += 1) {
    if (!used.has(index)) return index;
  }
  return assets.length;
}

function validateName(value: unknown): string {
  const name = String(value ?? "").trim();
  if (name.length < 1 || name.length > 16) {
    throw new HttpError(400, "模式名称需要 1-16 个字符");
  }
  return name;
}

function validateFullscreenAnimationName(value: unknown): string {
  const name = String(value ?? "").trim();
  if (name.length < 1 || name.length > 32) {
    throw new HttpError(400, "动画名称需要 1-32 个字符");
  }
  return name;
}

function validateFullscreenAnimationTriggerType(value: unknown): FullscreenAnimationTriggerType {
  if (value === "max_profit_day" || value === "birthday_home") return value;
  throw new HttpError(400, "触发类型必须是 max_profit_day 或 birthday_home");
}

function validateNickname(value: unknown): string {
  const nickname = String(value ?? "").trim();
  if (nickname.length < 1 || nickname.length > 24) {
    throw new HttpError(400, "昵称需要 1-24 个字符");
  }
  return nickname;
}

function validateBirthday(value: unknown): string | null {
  const birthday = String(value ?? "").trim();
  if (!birthday) return null;

  if (!/^\d{4}-\d{2}-\d{2}$/.test(birthday)) {
    throw new HttpError(400, "生日格式必须是 YYYY-MM-DD");
  }

  const date = new Date(`${birthday}T00:00:00Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== birthday) {
    throw new HttpError(400, "生日日期不合法");
  }

  return birthday;
}

function makeDefaultNickname(): string {
  const digits = Array.from({ length: 7 }, () => Math.floor(Math.random() * 10)).join("");
  return `众安_${digits}`;
}

function validateExtremeDayMessage(value: unknown): string {
  const message = String(value ?? "").trim();
  if (message.length < 1 || message.length > 80) {
    throw new HttpError(400, "文案需要 1-80 个字符");
  }
  return message;
}

function validateExtremeDayTriggerType(value: unknown): ExtremeDayTriggerType {
  if (value === "consecutive_loss" || value === "consecutive_profit" || value === "loss_to_profit" || value === "profit_to_loss") return value;
  throw new HttpError(400, "趋势文案触发类型不合法");
}

function validateSortOrder(value: unknown): number {
  const order = Number(value);
  if (!Number.isInteger(order) || order < 0 || order > 999) {
    throw new HttpError(400, "排序需要是 0-999 的整数");
  }
  return order;
}

function validateScope(value: unknown): MoodScope {
  if (value === "global" || value === "user") return value;
  throw new HttpError(400, "作用范围必须是 global 或 user");
}

function validateBehavior(value: unknown): MoodBehavior {
  if (value === "random" || value === "manual") return value;
  throw new HttpError(400, "玩法必须是 random 或 manual");
}

function validateKind(value: unknown): AssetKind {
  if (value === "default" || value === "profit" || value === "loss") return value;
  throw new HttpError(400, "资源类型必须是 default、profit 或 loss");
}

function validateUserID(scope: MoodScope, value: unknown): string | null {
  if (scope === "global") return null;
  return requireUUID(String(value ?? ""), "目标用户 ID");
}

function requireUUID(value: string, label: string): string {
  const normalized = String(value ?? "").trim();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(normalized)) {
    throw new HttpError(400, `${label} 格式不正确`);
  }
  return normalized;
}

function requireGIFFile(file: Express.Multer.File | undefined): Express.Multer.File {
  if (!file) throw new HttpError(400, "请选择 GIF 文件");
  const signature = file.buffer.subarray(0, 6).toString("ascii");
  if (signature !== "GIF87a" && signature !== "GIF89a") {
    throw new HttpError(400, "只支持 GIF 文件");
  }
  return file;
}

function requireLottieFile(file: Express.Multer.File | undefined): Express.Multer.File {
  if (!file) throw new HttpError(400, "请选择 .lottie 文件");
  const fileName = file.originalname.toLowerCase();
  if (!fileName.endsWith(".lottie")) {
    throw new HttpError(400, "只支持 .lottie 文件");
  }

  const signature = file.buffer.subarray(0, 2).toString("ascii");
  if (signature !== "PK") {
    throw new HttpError(400, ".lottie 文件格式不正确");
  }

  return file;
}

function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing ${key}. Please configure admin/.env.local`);
  }
  return value;
}

function loadLocalEnv(): void {
  const envPath = resolve(process.cwd(), ".env.local");
  if (!existsSync(envPath)) return;

  const lines = readFileSync(envPath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const separatorIndex = trimmed.indexOf("=");
    if (separatorIndex === -1) continue;
    const key = trimmed.slice(0, separatorIndex).trim();
    const value = trimmed.slice(separatorIndex + 1).trim();
    if (!process.env[key]) {
      process.env[key] = value.replace(/^['"]|['"]$/g, "");
    }
  }
}

function sendError(response: express.Response, error: unknown): void {
  if (error instanceof HttpError) {
    response.status(error.status).json({ error: error.message });
    return;
  }

  const message = error instanceof Error ? error.message : "未知错误";
  console.error(error);
  response.status(500).json({ error: message });
}

class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}
