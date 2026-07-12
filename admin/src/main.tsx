import React, { useEffect, useMemo, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  CheckCircle2,
  CalendarDays,
  Clapperboard,
  Clipboard,
  CloudUpload,
  Globe2,
  ImagePlus,
  LayoutDashboard,
  Loader2,
  Lock,
  MessageSquareQuote,
  Plus,
  RefreshCw,
  Save,
  Search,
  Sparkles,
  Trash2,
  UserRoundCheck,
  UsersRound,
  X,
  XCircle
} from "lucide-react";
import "./styles.css";

type SectionKey = "users" | "moods" | "fullscreen" | "birthdayAnimations" | "messages" | "ai";
type MoodScope = "global" | "user";
type MoodBehavior = "random" | "manual";
type AssetKind = "default" | "profit" | "loss";
type FullscreenAnimationTriggerType = "max_profit_day" | "birthday_home";
type ExtremeDayTriggerType = "consecutive_loss" | "consecutive_profit" | "loss_to_profit" | "profit_to_loss";

type MoodAsset = {
  id: string;
  mode_id: string;
  user_id: string | null;
  kind: AssetKind;
  sort_order: number;
  storage_path: string;
  signed_url: string | null;
};

type MoodMode = {
  id: string;
  user_id: string | null;
  scope: MoodScope;
  name: string;
  behavior: MoodBehavior;
  selected_profit_asset_id: string | null;
  selected_loss_asset_id: string | null;
  created_at: string;
  assets: MoodAsset[];
};

type AdminUser = {
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

type UserHolding = {
  id: string; user_id: string; stock_name: string; stock_code: string | null;
  market_value: number | null; quantity: number | null; current_price: number | null; cost_price: number | null;
  today_pnl: number | null; today_pnl_percent: number | null; holding_pnl: number | null;
  holding_pnl_percent: number | null; data_timestamp: string;
};

type StatUploadRecord = {
  id: string;
  user_id: string;
  nickname: string | null;
  timestamp: string;
  usd_amount: number;
};

type FullscreenAnimation = {
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
  signed_url: string | null;
};

type ExtremeDayMessage = {
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

type ModeDraft = {
  name: string;
  scope: MoodScope;
  userId: string;
  behavior: MoodBehavior;
};

type FullscreenAnimationDraft = {
  name: string;
  scope: MoodScope;
  userId: string;
  triggerType: FullscreenAnimationTriggerType;
};

type ExtremeDayMessageDraft = {
  scope: MoodScope;
  userId: string;
  triggerType: ExtremeDayTriggerType;
  message: string;
  sortOrder: number;
};

type AIConfigStatus = { configured: boolean; ready: boolean; models: Array<{ model: string; isPrimary: boolean }> };

const passwordStorageKey = "myliverate.mood_admin.password";

function App() {
  const [password, setPassword] = useState(() => localStorage.getItem(passwordStorageKey) ?? "");
  const [passwordInput, setPasswordInput] = useState("");
  const [activeSection, setActiveSection] = useState<SectionKey>("users");
  const [modes, setModes] = useState<MoodMode[]>([]);
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [uploadRecords, setUploadRecords] = useState<StatUploadRecord[]>([]);
  const [userHoldings, setUserHoldings] = useState<UserHolding[]>([]);
  const [fullscreenAnimations, setFullscreenAnimations] = useState<FullscreenAnimation[]>([]);
  const [extremeDayMessages, setExtremeDayMessages] = useState<ExtremeDayMessage[]>([]);
  const [selectedModeID, setSelectedModeID] = useState<string>("");
  const [selectedFullscreenAnimationID, setSelectedFullscreenAnimationID] = useState<string>("");
  const [selectedExtremeDayMessageID, setSelectedExtremeDayMessageID] = useState<string>("");
  const [selectedUserID, setSelectedUserID] = useState<string>("");
  const [selectedUserDetail, setSelectedUserDetail] = useState<AdminUser | null>(null);
  const [draft, setDraft] = useState<ModeDraft>({ name: "", scope: "global", userId: "", behavior: "random" });
  const [fullscreenDraft, setFullscreenDraft] = useState<FullscreenAnimationDraft>({
    name: "Money Stack",
    scope: "global",
    userId: "",
    triggerType: "max_profit_day"
  });
  const [messageDraft, setMessageDraft] = useState<ExtremeDayMessageDraft>({
    scope: "global",
    userId: "",
    triggerType: "consecutive_loss",
    message: "",
    sortOrder: 0
  });
  const [moodFilter, setMoodFilter] = useState<"all" | MoodScope>("all");
  const [userSearch, setUserSearch] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);
  const [aiStatus, setAIStatus] = useState<AIConfigStatus | null>(null);

  const selectedMode = modes.find((mode) => mode.id === selectedModeID) ?? modes[0] ?? null;
  const activeFullscreenTriggerType: FullscreenAnimationTriggerType = activeSection === "birthdayAnimations" ? "birthday_home" : "max_profit_day";
  const activeFullscreenAnimations = fullscreenAnimations.filter((animation) => animation.trigger_type === activeFullscreenTriggerType);
  const selectedFullscreenAnimation = activeFullscreenAnimations.find((animation) => animation.id === selectedFullscreenAnimationID) ?? activeFullscreenAnimations[0] ?? null;
  const selectedExtremeDayMessage = extremeDayMessages.find((item) => item.id === selectedExtremeDayMessageID) ?? extremeDayMessages[0] ?? null;
  const filteredModes = modes.filter((mode) => moodFilter === "all" || mode.scope === moodFilter);
  const filteredUsers = useMemo(() => {
    const keyword = userSearch.trim().toLowerCase();
    if (!keyword) return users;
    return users.filter((user) =>
      user.id.toLowerCase().includes(keyword)
      || (user.email ?? "").toLowerCase().includes(keyword)
      || (user.nickname ?? "").toLowerCase().includes(keyword)
      || (user.birthday ?? "").includes(keyword)
    );
  }, [users, userSearch]);

  useEffect(() => {
    if (!password) return;
    void loadUsers();
    void loadUploadRecords();
    void loadModes();
    void loadFullscreenAnimations();
    void loadExtremeDayMessages();
  }, [password]);

  useEffect(() => {
    if (!selectedMode) {
      setDraft({ name: "", scope: "global", userId: "", behavior: "random" });
      return;
    }

    setSelectedModeID(selectedMode.id);
    setDraft({
      name: selectedMode.name,
      scope: selectedMode.scope,
      userId: selectedMode.user_id ?? "",
      behavior: selectedMode.behavior
    });
  }, [selectedMode?.id]);

  useEffect(() => {
    if (!selectedFullscreenAnimation) {
      setFullscreenDraft({
        name: activeFullscreenTriggerType === "birthday_home" ? "Birthday Party" : "Money Stack",
        scope: "global",
        userId: "",
        triggerType: activeFullscreenTriggerType
      });
      return;
    }

    setSelectedFullscreenAnimationID(selectedFullscreenAnimation.id);
    setFullscreenDraft({
      name: selectedFullscreenAnimation.name,
      scope: selectedFullscreenAnimation.scope,
      userId: selectedFullscreenAnimation.user_id ?? "",
      triggerType: selectedFullscreenAnimation.trigger_type
    });
  }, [selectedFullscreenAnimation?.id, activeFullscreenTriggerType]);

  useEffect(() => {
    if (!selectedExtremeDayMessage) {
      setMessageDraft({
        scope: "global",
        userId: "",
        triggerType: "consecutive_loss",
        message: "",
        sortOrder: 0
      });
      return;
    }

    setSelectedExtremeDayMessageID(selectedExtremeDayMessage.id);
    setMessageDraft({
      scope: selectedExtremeDayMessage.scope,
      userId: selectedExtremeDayMessage.user_id ?? "",
      triggerType: selectedExtremeDayMessage.trigger_type,
      message: selectedExtremeDayMessage.message,
      sortOrder: selectedExtremeDayMessage.sort_order
    });
  }, [selectedExtremeDayMessage?.id]);

  async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
    const response = await fetch(path, {
      ...init,
      headers: {
        "x-admin-password": password,
        ...(init.body instanceof FormData ? {} : { "Content-Type": "application/json" }),
        ...init.headers
      }
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload.error ?? "请求失败");
    }
    return payload as T;
  }

  async function loadAIStatus() {
    setIsLoading(true);
    try { setAIStatus(await api<AIConfigStatus>("/api/ai-config/status")); }
    catch (error) { showError(error); }
    finally { setIsLoading(false); }
  }

  async function testAIConfig(draft: { apiKey: string; baseUrl: string; model: string }) {
    setIsSaving(true); setMessage(null);
    try {
      const result = await api<{ success: boolean; message: string; model: string; latencyMs: number | null }>("/api/ai-config/test", { method: "POST", body: JSON.stringify(draft) });
      if (!result.success) throw new Error(result.message);
      setMessage({ type: "success", text: `连接成功：${result.model}${result.latencyMs ? ` · ${result.latencyMs}ms` : ""}` });
      return true;
    } catch (error) { showError(error); return false; }
    finally { setIsSaving(false); }
  }

  async function saveAIConfig(draft: { apiKey: string; baseUrl: string; model: string }) {
    setIsSaving(true); setMessage(null);
    try {
      await api("/api/ai-config", { method: "PUT", body: JSON.stringify(draft) });
      await loadAIStatus();
      setMessage({ type: "success", text: "AI 大模型配置已保存并生效" });
      return true;
    } catch (error) { showError(error); return false; }
    finally { setIsSaving(false); }
  }

  async function login(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsLoading(true);
    setMessage(null);
    try {
      const response = await fetch("/api/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ password: passwordInput })
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(payload.error ?? "密码不正确");
      localStorage.setItem(passwordStorageKey, passwordInput);
      setPassword(passwordInput);
      setPasswordInput("");
    } catch (error) {
      showError(error);
    } finally {
      setIsLoading(false);
    }
  }

  async function loadUsers() {
    setIsLoading(true);
    setMessage(null);
    try {
      const payload = await api<{ users: AdminUser[] }>("/api/users");
      setUsers(payload.users);
      if (!selectedUserID && payload.users.length > 0) {
        const firstUser = payload.users[0];
        setSelectedUserID(firstUser.id);
        setSelectedUserDetail(firstUser);
        const holdingPayload = await api<{ holdings: UserHolding[] }>(`/api/users/${firstUser.id}/holdings`);
        setUserHoldings(holdingPayload.holdings);
      }
    } catch (error) {
      showError(error);
    } finally {
      setIsLoading(false);
    }
  }

  async function refreshUserManagement() {
    const currentUserID = selectedUserID;
    await loadUsers();
    if (currentUserID) {
      await loadUserDetail(currentUserID);
    }
    await loadUploadRecords();
    setMessage({ type: "success", text: "用户、持仓和上传记录已刷新" });
  }

  async function loadUserDetail(userID: string) {
    setSelectedUserID(userID);
    setSelectedUserDetail(users.find((user) => user.id === userID) ?? null);
    setMessage(null);
    try {
      const payload = await api<{ user: AdminUser }>(`/api/users/${userID}`);
      setSelectedUserDetail(payload.user);
      const holdingPayload = await api<{ holdings: UserHolding[] }>(`/api/users/${userID}/holdings`);
      setUserHoldings(holdingPayload.holdings);
    } catch (error) {
      showError(error);
    }
  }

  async function saveUserHolding(holding: UserHolding) {
    setIsSaving(true); setMessage(null);
    try {
      const payload = await api<{ holding: UserHolding }>(`/api/users/${holding.user_id}/holdings/${holding.id}`, {
        method: "PATCH", body: JSON.stringify(holding)
      });
      setUserHoldings((items) => items.map((item) => item.id === payload.holding.id ? payload.holding : item));
      setMessage({ type: "success", text: "持仓已更新" });
      return true;
    } catch (error) { showError(error); return false; }
    finally { setIsSaving(false); }
  }

  async function deleteUserHolding(holding: UserHolding) {
    if (!window.confirm(`删除「${holding.stock_name}」持仓？`)) return;
    setIsSaving(true); setMessage(null);
    try {
      await api(`/api/users/${holding.user_id}/holdings/${holding.id}`, { method: "DELETE" });
      setUserHoldings((items) => items.filter((item) => item.id !== holding.id));
      if (selectedUserDetail) setSelectedUserDetail({ ...selectedUserDetail, holding_count: Math.max(0, (selectedUserDetail.holding_count ?? 1) - 1) });
      setMessage({ type: "success", text: "持仓已删除" });
    } catch (error) { showError(error); }
    finally { setIsSaving(false); }
  }

  async function saveUserProfile(userID: string, birthday: string) {
    const currentUser = selectedUserDetail ?? users.find((user) => user.id === userID);
    if (!currentUser) return false;

    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ user: AdminUser }>(`/api/users/${userID}/profile`, {
        method: "PATCH",
        body: JSON.stringify({
          nickname: currentUser.nickname,
          birthday
        })
      });
      setSelectedUserDetail(payload.user);
      setUsers((currentUsers) => currentUsers.map((user) => user.id === payload.user.id ? { ...user, ...payload.user } : user));
      setMessage({ type: "success", text: birthday ? "生日已保存" : "生日已清空" });
      return true;
    } catch (error) {
      showError(error);
      return false;
    } finally {
      setIsSaving(false);
    }
  }

  async function loadModes() {
    setIsLoading(true);
    setMessage(null);
    try {
      const payload = await api<{ modes: MoodMode[] }>("/api/modes");
      setModes(payload.modes);
      if (!selectedModeID && payload.modes.length > 0) {
        setSelectedModeID(payload.modes[0].id);
      }
    } catch (error) {
      showError(error);
    } finally {
      setIsLoading(false);
    }
  }

  async function loadUploadRecords() {
    setIsLoading(true);
    setMessage(null);
    try {
      const payload = await api<{ records: StatUploadRecord[] }>("/api/stat-upload-records");
      setUploadRecords(payload.records);
    } catch (error) {
      showError(error);
    } finally {
      setIsLoading(false);
    }
  }

  async function loadFullscreenAnimations() {
    setIsLoading(true);
    setMessage(null);
    try {
      const payload = await api<{ animations: FullscreenAnimation[] }>("/api/fullscreen-animations");
      setFullscreenAnimations(payload.animations);
      if (!selectedFullscreenAnimationID && payload.animations.length > 0) {
        setSelectedFullscreenAnimationID(payload.animations[0].id);
      }
    } catch (error) {
      showError(error);
    } finally {
      setIsLoading(false);
    }
  }

  async function loadExtremeDayMessages() {
    setIsLoading(true);
    setMessage(null);
    try {
      const payload = await api<{ messages: ExtremeDayMessage[] }>("/api/trend-messages");
      setExtremeDayMessages(payload.messages);
      if (!selectedExtremeDayMessageID && payload.messages.length > 0) {
        setSelectedExtremeDayMessageID(payload.messages[0].id);
      }
    } catch (error) {
      showError(error);
    } finally {
      setIsLoading(false);
    }
  }

  async function createFullscreenAnimation(file: File, triggerType = fullscreenDraft.triggerType) {
    const formData = new FormData();
    formData.append("name", fullscreenDraft.name);
    formData.append("scope", fullscreenDraft.scope);
    formData.append("userId", fullscreenDraft.userId);
    formData.append("triggerType", triggerType);
    formData.append("file", file);
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ animations: FullscreenAnimation[] }>("/api/fullscreen-animations", {
        method: "POST",
        body: formData
      });
      setFullscreenAnimations(payload.animations);
      if (payload.animations[0]?.id) setSelectedFullscreenAnimationID(payload.animations[0].id);
      setMessage({ type: "success", text: "全屏动画已上传" });
      return true;
    } catch (error) {
      showError(error);
      return false;
    } finally {
      setIsSaving(false);
    }
  }

  async function saveFullscreenAnimation(triggerType = fullscreenDraft.triggerType) {
    if (!selectedFullscreenAnimation) return false;
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ animations: FullscreenAnimation[] }>(`/api/fullscreen-animations/${selectedFullscreenAnimation.id}`, {
        method: "PATCH",
        body: JSON.stringify({ ...fullscreenDraft, triggerType })
      });
      setFullscreenAnimations(payload.animations);
      setMessage({ type: "success", text: "全屏动画已保存" });
      return true;
    } catch (error) {
      showError(error);
      return false;
    } finally {
      setIsSaving(false);
    }
  }

  async function toggleFullscreenAnimation(animationID: string, isEnabled: boolean) {
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ animations: FullscreenAnimation[] }>(`/api/fullscreen-animations/${animationID}`, {
        method: "PATCH",
        body: JSON.stringify({ isEnabled })
      });
      setFullscreenAnimations(payload.animations);
      setMessage({ type: "success", text: isEnabled ? "动画已启用" : "动画已停用" });
    } catch (error) {
      showError(error);
    } finally {
      setIsSaving(false);
    }
  }

  async function replaceFullscreenAnimation(file: File) {
    if (!selectedFullscreenAnimation) return false;
    const formData = new FormData();
    formData.append("file", file);
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ animations: FullscreenAnimation[] }>(`/api/fullscreen-animations/${selectedFullscreenAnimation.id}/replace`, {
        method: "POST",
        body: formData
      });
      setFullscreenAnimations(payload.animations);
      setMessage({ type: "success", text: "全屏动画已替换" });
      return true;
    } catch (error) {
      showError(error);
      return false;
    } finally {
      setIsSaving(false);
    }
  }

  async function deleteFullscreenAnimation() {
    if (!selectedFullscreenAnimation) return;
    if (!window.confirm(`删除「${selectedFullscreenAnimation.name}」？`)) return;
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ animations: FullscreenAnimation[] }>(`/api/fullscreen-animations/${selectedFullscreenAnimation.id}`, { method: "DELETE" });
      setFullscreenAnimations(payload.animations);
      setSelectedFullscreenAnimationID(payload.animations[0]?.id ?? "");
      setMessage({ type: "success", text: "全屏动画已删除" });
    } catch (error) {
      showError(error);
    } finally {
      setIsSaving(false);
    }
  }

  async function createExtremeDayMessage() {
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ messages: ExtremeDayMessage[] }>("/api/trend-messages", {
        method: "POST",
        body: JSON.stringify(messageDraft)
      });
      setExtremeDayMessages(payload.messages);
      if (payload.messages[0]?.id) setSelectedExtremeDayMessageID(payload.messages[0].id);
      setMessage({ type: "success", text: "趋势文案已新增" });
      return true;
    } catch (error) {
      showError(error);
      return false;
    } finally {
      setIsSaving(false);
    }
  }

  async function saveExtremeDayMessage() {
    if (!selectedExtremeDayMessage) return false;
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ messages: ExtremeDayMessage[] }>(`/api/trend-messages/${selectedExtremeDayMessage.id}`, {
        method: "PATCH",
        body: JSON.stringify(messageDraft)
      });
      setExtremeDayMessages(payload.messages);
      setMessage({ type: "success", text: "趋势文案已保存" });
      return true;
    } catch (error) {
      showError(error);
      return false;
    } finally {
      setIsSaving(false);
    }
  }

  async function toggleExtremeDayMessage(messageID: string, isEnabled: boolean) {
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ messages: ExtremeDayMessage[] }>(`/api/trend-messages/${messageID}`, {
        method: "PATCH",
        body: JSON.stringify({ isEnabled })
      });
      setExtremeDayMessages(payload.messages);
      setMessage({ type: "success", text: isEnabled ? "文案已启用" : "文案已停用" });
    } catch (error) {
      showError(error);
    } finally {
      setIsSaving(false);
    }
  }

  async function deleteExtremeDayMessage() {
    if (!selectedExtremeDayMessage) return;
    if (!window.confirm("删除这条趋势文案？")) return;
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ messages: ExtremeDayMessage[] }>(`/api/trend-messages/${selectedExtremeDayMessage.id}`, { method: "DELETE" });
      setExtremeDayMessages(payload.messages);
      setSelectedExtremeDayMessageID(payload.messages[0]?.id ?? "");
      setMessage({ type: "success", text: "趋势文案已删除" });
    } catch (error) {
      showError(error);
    } finally {
      setIsSaving(false);
    }
  }

  async function createMode() {
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ mode: MoodMode }>("/api/modes", {
        method: "POST",
        body: JSON.stringify(draft)
      });
      await loadModes();
      if (payload.mode?.id) setSelectedModeID(payload.mode.id);
      setMessage({ type: "success", text: "模式已创建" });
      return true;
    } catch (error) {
      showError(error);
      return false;
    } finally {
      setIsSaving(false);
    }
  }

  async function saveMode() {
    if (!selectedMode) return false;
    setIsSaving(true);
    setMessage(null);
    try {
      await api(`/api/modes/${selectedMode.id}`, {
        method: "PATCH",
        body: JSON.stringify(draft)
      });
      await loadModes();
      setMessage({ type: "success", text: "模式已保存" });
      return true;
    } catch (error) {
      showError(error);
      return false;
    } finally {
      setIsSaving(false);
    }
  }

  async function deleteMode() {
    if (!selectedMode) return;
    if (!window.confirm(`删除「${selectedMode.name}」以及所有 GIF？`)) return;
    setIsSaving(true);
    setMessage(null);
    try {
      await api(`/api/modes/${selectedMode.id}`, { method: "DELETE" });
      const nextModes = modes.filter((mode) => mode.id !== selectedMode.id);
      setModes(nextModes);
      setSelectedModeID(nextModes[0]?.id ?? "");
      setMessage({ type: "success", text: "模式已删除" });
    } catch (error) {
      showError(error);
    } finally {
      setIsSaving(false);
    }
  }

  async function uploadAsset(kind: AssetKind, file: File) {
    if (!selectedMode) return false;
    const formData = new FormData();
    formData.append("kind", kind);
    formData.append("file", file);
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ modes: MoodMode[] }>(`/api/modes/${selectedMode.id}/assets`, {
        method: "POST",
        body: formData
      });
      setModes(payload.modes);
      setMessage({ type: "success", text: "GIF 已上传" });
      return true;
    } catch (error) {
      showError(error);
      return false;
    } finally {
      setIsSaving(false);
    }
  }

  async function replaceAsset(assetID: string, file: File) {
    const formData = new FormData();
    formData.append("file", file);
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ modes: MoodMode[] }>(`/api/assets/${assetID}/replace`, {
        method: "POST",
        body: formData
      });
      setModes(payload.modes);
      setMessage({ type: "success", text: "GIF 已替换" });
      return true;
    } catch (error) {
      showError(error);
      return false;
    } finally {
      setIsSaving(false);
    }
  }

  async function selectAsset(assetID: string) {
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ modes: MoodMode[] }>(`/api/assets/${assetID}/select`, { method: "PATCH" });
      setModes(payload.modes);
      setMessage({ type: "success", text: "手动选择已更新" });
    } catch (error) {
      showError(error);
    } finally {
      setIsSaving(false);
    }
  }

  async function deleteAsset(assetID: string) {
    if (!window.confirm("删除这张 GIF？")) return;
    setIsSaving(true);
    setMessage(null);
    try {
      const payload = await api<{ modes: MoodMode[] }>(`/api/assets/${assetID}`, { method: "DELETE" });
      setModes(payload.modes);
      setMessage({ type: "success", text: "GIF 已删除" });
    } catch (error) {
      showError(error);
    } finally {
      setIsSaving(false);
    }
  }

  async function copyUserID(userID: string) {
    await navigator.clipboard.writeText(userID);
    setMessage({ type: "success", text: "用户 ID 已复制" });
  }

  function logout() {
    localStorage.removeItem(passwordStorageKey);
    setPassword("");
    setModes([]);
    setUsers([]);
    setUploadRecords([]);
    setFullscreenAnimations([]);
    setExtremeDayMessages([]);
  }

  function showError(error: unknown) {
    setMessage({ type: "error", text: error instanceof Error ? error.message : "操作失败" });
  }

  if (!password) {
    return (
      <main className="login-shell">
        <form className="login-panel" onSubmit={login}>
          <div className="login-icon"><LayoutDashboard size={22} /></div>
          <span className="brand-kicker">LIVE / RATE · OPS</span>
          <h1>众安助手管理</h1>
          <p>本地后台工作台，管理用户信息与运营资源。</p>
          <label htmlFor="password">后台密码</label>
          <input
            id="password"
            type="password"
            value={passwordInput}
            onChange={(event) => setPasswordInput(event.target.value)}
            placeholder="输入 ADMIN_PASSWORD"
          />
          <button className="primary-button" type="submit" disabled={isLoading || !passwordInput}>
            {isLoading ? <Loader2 className="spin" size={18} /> : <Lock size={18} />}
            登录
          </button>
          {message && <StatusMessage message={message} />}
        </form>
      </main>
    );
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand-row">
          <div className="brand-mark"><LayoutDashboard size={20} /></div>
          <div className="brand-copy">
            <span className="brand-kicker">LIVE / RATE</span>
            <h1>众安助手管理</h1>
            <p>本地运营后台</p>
          </div>
        </div>

        <nav className="module-nav" aria-label="后台模块">
          <button
            type="button"
            className={activeSection === "users" ? "active" : ""}
            onClick={() => setActiveSection("users")}
          >
            <UsersRound size={18} />
            <span>
              <strong>用户管理</strong>
              <small>{users.length} 个用户</small>
            </span>
          </button>
          <button
            type="button"
            className={activeSection === "moods" ? "active" : ""}
            onClick={() => setActiveSection("moods")}
          >
            <Sparkles size={18} />
            <span>
              <strong>表情管理</strong>
              <small>{modes.length} 个模式</small>
            </span>
          </button>
          <button
            type="button"
            className={activeSection === "fullscreen" ? "active" : ""}
            onClick={() => setActiveSection("fullscreen")}
          >
            <Clapperboard size={18} />
            <span>
              <strong>全屏动画</strong>
              <small>{fullscreenAnimations.filter((animation) => animation.trigger_type === "max_profit_day").length} 个动画</small>
            </span>
          </button>
          <button
            type="button"
            className={activeSection === "birthdayAnimations" ? "active" : ""}
            onClick={() => setActiveSection("birthdayAnimations")}
          >
            <CalendarDays size={18} />
            <span>
              <strong>生日动画</strong>
              <small>{fullscreenAnimations.filter((animation) => animation.trigger_type === "birthday_home").length} 个动画</small>
            </span>
          </button>
          <button
            type="button"
            className={activeSection === "messages" ? "active" : ""}
            onClick={() => setActiveSection("messages")}
          >
            <MessageSquareQuote size={18} />
            <span>
              <strong>趋势文案</strong>
              <small>{extremeDayMessages.length} 条文案</small>
            </span>
          </button>
          <button
            type="button"
            className={activeSection === "ai" ? "active" : ""}
            onClick={() => { setActiveSection("ai"); void loadAIStatus(); }}
          >
            <Sparkles size={18} />
            <span>
              <strong>AI 大模型</strong>
              <small>{aiStatus?.configured ? "已配置" : "待配置"}</small>
            </span>
          </button>
        </nav>

        <button className="ghost-button" type="button" onClick={logout}>退出后台</button>
      </aside>

      <section className="workspace">
        {message && <StatusMessage message={message} />}

        {activeSection === "ai" ? (
          <AIModelManagementView status={aiStatus} isLoading={isLoading} isSaving={isSaving} onRefresh={loadAIStatus} onTest={testAIConfig} onSave={saveAIConfig} />
        ) : activeSection === "users" ? (
          <UserManagementView
            users={filteredUsers}
            allUsers={users}
            search={userSearch}
            selectedUserID={selectedUserID}
            selectedUserDetail={selectedUserDetail}
            uploadRecords={uploadRecords}
            holdings={userHoldings}
            isLoading={isLoading}
            onSearchChange={setUserSearch}
            onRefresh={refreshUserManagement}
            onRefreshRecords={loadUploadRecords}
            onSelectUser={loadUserDetail}
            onCopyUserID={copyUserID}
            onSaveUserProfile={saveUserProfile}
            onSaveHolding={saveUserHolding}
            onDeleteHolding={deleteUserHolding}
            isSaving={isSaving}
          />
        ) : activeSection === "fullscreen" ? (
          <FullscreenAnimationManagementView
            animations={activeFullscreenAnimations}
            selectedAnimation={selectedFullscreenAnimation}
            draft={fullscreenDraft}
            fixedTriggerType="max_profit_day"
            title="全屏动画"
            eyebrow="Fullscreen"
            description="上传统计页最大盈利日播放的 dotLottie 动画，支持全局和指定用户。"
            listDescription="这里只管理最大盈利日触发的动画。"
            isLoading={isLoading}
            isSaving={isSaving}
            onDraftChange={setFullscreenDraft}
            onRefresh={loadFullscreenAnimations}
            onSelectAnimation={setSelectedFullscreenAnimationID}
            onCreate={createFullscreenAnimation}
            onSave={saveFullscreenAnimation}
            onToggle={toggleFullscreenAnimation}
            onReplace={replaceFullscreenAnimation}
            onDelete={deleteFullscreenAnimation}
          />
        ) : activeSection === "birthdayAnimations" ? (
          <FullscreenAnimationManagementView
            animations={activeFullscreenAnimations}
            selectedAnimation={selectedFullscreenAnimation}
            draft={fullscreenDraft}
            fixedTriggerType="birthday_home"
            title="生日动画"
            eyebrow="Birthday"
            description="上传首页生日当天播放的 dotLottie 动画，支持全局和指定用户。"
            listDescription="这里只管理生日首页触发的动画。"
            isLoading={isLoading}
            isSaving={isSaving}
            onDraftChange={setFullscreenDraft}
            onRefresh={loadFullscreenAnimations}
            onSelectAnimation={setSelectedFullscreenAnimationID}
            onCreate={createFullscreenAnimation}
            onSave={saveFullscreenAnimation}
            onToggle={toggleFullscreenAnimation}
            onReplace={replaceFullscreenAnimation}
            onDelete={deleteFullscreenAnimation}
          />
        ) : activeSection === "messages" ? (
          <ExtremeDayMessageManagementView
            messages={extremeDayMessages}
            selectedMessage={selectedExtremeDayMessage}
            draft={messageDraft}
            isLoading={isLoading}
            isSaving={isSaving}
            onDraftChange={setMessageDraft}
            onRefresh={loadExtremeDayMessages}
            onSelectMessage={setSelectedExtremeDayMessageID}
            onCreate={createExtremeDayMessage}
            onSave={saveExtremeDayMessage}
            onToggle={toggleExtremeDayMessage}
            onDelete={deleteExtremeDayMessage}
          />
        ) : (
          <MoodManagementView
            modes={modes}
            filteredModes={filteredModes}
            selectedMode={selectedMode}
            draft={draft}
            filter={moodFilter}
            isLoading={isLoading}
            isSaving={isSaving}
            onDraftChange={setDraft}
            onFilterChange={setMoodFilter}
            onRefresh={loadModes}
            onCreateMode={createMode}
            onSaveMode={saveMode}
            onDeleteMode={deleteMode}
            onSelectMode={setSelectedModeID}
            onUpload={uploadAsset}
            onReplace={replaceAsset}
            onSelectAsset={selectAsset}
            onDeleteAsset={deleteAsset}
          />
        )}
      </section>
    </main>
  );
}

function AIModelManagementView({ status, isLoading, isSaving, onRefresh, onTest, onSave }: {
  status: AIConfigStatus | null; isLoading: boolean; isSaving: boolean;
  onRefresh: () => Promise<void>;
  onTest: (draft: { apiKey: string; baseUrl: string; model: string }) => Promise<boolean>;
  onSave: (draft: { apiKey: string; baseUrl: string; model: string }) => Promise<boolean>;
}) {
  const [apiKey, setAPIKey] = useState("");
  const [baseUrl, setBaseUrl] = useState("https://open-gateway.anspire.cn/v6");
  const [model, setModel] = useState("Doubao-Seed-2.0-lite");
  const draft = { apiKey, baseUrl, model };
  return <section className="management-page">
    <div className="page-heading"><div><p className="eyebrow">AI Model</p><h2>AI 大模型</h2><p>配置持仓 AI 分析使用的模型渠道。密钥只发送到本地后台服务，不会返回浏览器。</p></div>
      <button type="button" className="secondary-button" onClick={() => void onRefresh()} disabled={isLoading}>{isLoading ? <Loader2 className="spin" size={17} /> : <RefreshCw size={17} />}刷新状态</button>
    </div>
    <div className="detail-panel">
      <div className="panel-title"><div><p className="eyebrow">Connection</p><h3>模型连接</h3><p>{status?.configured ? "主模型已经配置，可替换密钥或模型。" : "填写密钥并完成连接测试后启用。"}</p></div><StatusPill tone={status?.ready ? "success" : "warning"}>{status?.ready ? "服务就绪" : "待配置"}</StatusPill></div>
      <div className="form-grid">
        <label className="field full"><span>API Key</span><input type="password" autoComplete="new-password" value={apiKey} onChange={(event) => setAPIKey(event.target.value)} placeholder="输入新的模型 API Key" /><small>出于安全考虑，后台不会回显已保存的密钥。</small></label>
        <label className="field"><span>API Base URL</span><input value={baseUrl} onChange={(event) => setBaseUrl(event.target.value)} /></label>
        <label className="field"><span>主模型</span><input value={model} onChange={(event) => setModel(event.target.value)} /></label>
      </div>
      <div className="modal-actions"><button type="button" className="secondary-button" disabled={isSaving || apiKey.length < 8} onClick={() => void onTest(draft)}>{isSaving ? <Loader2 className="spin" size={17} /> : <CheckCircle2 size={17} />}测试连接</button><button type="button" className="primary-button" disabled={isSaving || apiKey.length < 8} onClick={() => void onSave(draft)}>{isSaving ? <Loader2 className="spin" size={17} /> : <Save size={17} />}保存并启用</button></div>
      {status?.models?.length ? <div className="readonly-grid"><DetailItem label="当前主模型" value={status.models.find((item) => item.isPrimary)?.model ?? status.models[0].model} /><DetailItem label="可用模型" value={`${status.models.length} 个`} /></div> : null}
    </div>
  </section>;
}

function UserManagementView({
  users,
  allUsers,
  search,
  selectedUserID,
  selectedUserDetail,
  uploadRecords,
  holdings,
  isLoading,
  isSaving,
  onSearchChange,
  onRefresh,
  onRefreshRecords,
  onSelectUser,
  onCopyUserID,
  onSaveUserProfile
  ,onSaveHolding,
  onDeleteHolding
}: {
  users: AdminUser[];
  allUsers: AdminUser[];
  search: string;
  selectedUserID: string;
  selectedUserDetail: AdminUser | null;
  uploadRecords: StatUploadRecord[];
  holdings: UserHolding[];
  isLoading: boolean;
  isSaving: boolean;
  onSearchChange: (value: string) => void;
  onRefresh: () => Promise<void>;
  onRefreshRecords: () => Promise<void>;
  onSelectUser: (userID: string) => Promise<void>;
  onCopyUserID: (userID: string) => Promise<void>;
  onSaveUserProfile: (userID: string, birthday: string) => Promise<boolean>;
  onSaveHolding: (holding: UserHolding) => Promise<boolean>;
  onDeleteHolding: (holding: UserHolding) => Promise<void>;
}) {
  const syncedProfiles = allUsers.filter((user) => user.profile_status === "synced").length;
  const anonymousUsers = allUsers.filter((user) => user.is_anonymous).length;
  const birthdayUsers = allUsers.filter((user) => user.birthday).length;
  const selectedUserRecords = uploadRecords.filter((record) => record.user_id === selectedUserID);

  return (
    <>
      <SectionHeader
        eyebrow="Users"
        title="用户管理"
        description="查看 Apple 登录用户、昵称资料与统计数据概况。"
        action={
          <button type="button" className="secondary-button" onClick={() => void onRefresh()} disabled={isLoading}>
            {isLoading ? <Loader2 className="spin" size={17} /> : <RefreshCw size={17} />}
            刷新
          </button>
        }
      />

      <div className="metric-grid">
        <MetricCard label="用户总数" value={allUsers.length.toString()} />
        <MetricCard label="已同步昵称" value={syncedProfiles.toString()} />
        <MetricCard label="已填生日" value={birthdayUsers.toString()} />
        <MetricCard label="匿名用户" value={anonymousUsers.toString()} />
      </div>

      <section className="user-workbench">
        <aside className="user-rail panel">
          <div className="panel-title compact"><div><h3>用户</h3><p>{users.length} 个匹配用户</p></div></div>
          <label className="search-field user-search"><Search size={17} /><input value={search} onChange={(event) => onSearchChange(event.target.value)} placeholder="搜索昵称 / 邮箱 / ID" /></label>
          <div className="user-list" role="list">
            {users.map((user) => (
              <button key={user.id} type="button" className={`user-row ${selectedUserID === user.id ? "selected" : ""}`} onClick={() => void onSelectUser(user.id)}>
                <span className="user-row-avatar">{(user.nickname ?? user.email ?? "U").slice(0, 1).toUpperCase()}</span>
                <span className="user-row-copy"><strong>{user.nickname ?? "未设置昵称"}</strong><small>{user.email ?? shortID(user.id)}</small></span>
                <StatusPill tone={user.profile_status === "synced" ? "success" : "warning"}>{user.profile_status === "synced" ? "正常" : "缺资料"}</StatusPill>
              </button>
            ))}
            {users.length === 0 && <div className="empty-state">暂无匹配用户</div>}
          </div>
        </aside>

        <div className="user-content">
          <UserDetailPanel user={selectedUserDetail} isSaving={isSaving} onCopyUserID={onCopyUserID} onSaveProfile={onSaveUserProfile} />
          <UserHoldingsPanel holdings={holdings} selectedUserID={selectedUserID} isSaving={isSaving} onSave={onSaveHolding} onDelete={onDeleteHolding} />
          <section className="panel user-records-panel">
            <div className="panel-title"><div><p className="eyebrow">Upload history</p><h3>上传记录</h3><p>当前用户最近的统计上传数据。</p></div><button type="button" className="secondary-button" onClick={() => void onRefreshRecords()} disabled={isLoading}>{isLoading ? <Loader2 className="spin" size={17} /> : <RefreshCw size={17} />}刷新</button></div>
            <div className="table-wrap"><table className="data-table records-table user-records-table"><thead><tr><th>上传时间</th><th>美元金额</th><th>记录 ID</th></tr></thead><tbody>{selectedUserRecords.map((record) => <tr key={record.id}><td>{formatDate(record.timestamp)}</td><td><strong className={record.usd_amount >= 0 ? "amount-profit" : "amount-loss"}>{formatUSD(record.usd_amount)}</strong></td><td><small>{shortID(record.id)}</small></td></tr>)}</tbody></table>{selectedUserID && selectedUserRecords.length === 0 && <div className="empty-state">该用户暂无上传记录</div>}{!selectedUserID && <div className="empty-state">请先选择用户</div>}</div>
          </section>
        </div>
      </section>
    </>
  );
}

function UserHoldingsPanel({ holdings, selectedUserID, isSaving, onSave, onDelete }: {
  holdings: UserHolding[]; selectedUserID: string; isSaving: boolean;
  onSave: (holding: UserHolding) => Promise<boolean>; onDelete: (holding: UserHolding) => Promise<void>;
}) {
  const [editing, setEditing] = useState<UserHolding | null>(null);
  const numberText = (value: number | null) => value == null ? "--" : value.toLocaleString("zh-CN", { maximumFractionDigits: 4 });
  const setNumber = (key: keyof UserHolding, value: string) => {
    if (!editing) return;
    setEditing({ ...editing, [key]: value.trim() === "" ? null : Number(value) });
  };
  return <section className="panel user-records-panel">
    <div className="panel-title"><div><p className="eyebrow">Holdings</p><h3>当前持仓</h3><p>与用户 App 同步的最新持仓数据。</p></div><StatusPill tone="success">{holdings.length} 条</StatusPill></div>
    <div className="table-wrap"><table className="data-table holdings-table"><thead><tr><th>股票</th><th>市值 / 数量</th><th>现价 / 成本</th><th>今日盈亏</th><th>持仓盈亏</th><th>操作</th></tr></thead>
      <tbody>{holdings.map((item) => <tr key={item.id}><td><strong>{item.stock_name}</strong><small>{item.stock_code ?? "无代码"}</small></td><td>{numberText(item.market_value)} / {numberText(item.quantity)}</td><td>{numberText(item.current_price)} / {numberText(item.cost_price)}</td><td className={(item.today_pnl ?? 0) >= 0 ? "amount-profit" : "amount-loss"}>{numberText(item.today_pnl)} / {numberText(item.today_pnl_percent)}%</td><td className={(item.holding_pnl ?? 0) >= 0 ? "amount-profit" : "amount-loss"}>{numberText(item.holding_pnl)} / {numberText(item.holding_pnl_percent)}%</td><td><div className="card-actions"><button className="tiny-button" onClick={() => setEditing({ ...item })}>编辑</button><button className="tiny-button danger" onClick={() => void onDelete(item)}><Trash2 size={14} />删除</button></div></td></tr>)}</tbody>
    </table>{selectedUserID && holdings.length === 0 && <div className="empty-state">该用户暂无持仓</div>}{!selectedUserID && <div className="empty-state">请先选择用户</div>}</div>
    {editing && <Modal title="编辑持仓" description={`修改 ${editing.stock_name} 的持仓数据。`} dirty isSaving={isSaving} onClose={() => setEditing(null)} footer={<><button className="secondary-button" disabled={isSaving} onClick={() => setEditing(null)}>取消</button><button className="primary-button" disabled={isSaving || !editing.stock_name.trim()} onClick={async () => { if (await onSave(editing)) setEditing(null); }}><Save size={17} />保存</button></>}>
      <div className="form-grid holding-form">
        <label>股票名称<input value={editing.stock_name} onChange={(e) => setEditing({ ...editing, stock_name: e.target.value })} /></label>
        <label>股票代码<input value={editing.stock_code ?? ""} onChange={(e) => setEditing({ ...editing, stock_code: e.target.value || null })} /></label>
        {([['market_value','市值'],['quantity','数量'],['current_price','现价'],['cost_price','成本'],['today_pnl','今日盈亏'],['today_pnl_percent','今日盈亏 %'],['holding_pnl','持仓盈亏'],['holding_pnl_percent','持仓盈亏 %']] as Array<[keyof UserHolding,string]>).map(([key,label]) => <label key={key}>{label}<input type="number" step="any" value={(editing[key] as number | null) ?? ""} onChange={(e) => setNumber(key, e.target.value)} /></label>)}
      </div>
    </Modal>}
  </section>;
}

function UserDetailPanel({
  user,
  isSaving,
  onCopyUserID,
  onSaveProfile
}: {
  user: AdminUser | null;
  isSaving: boolean;
  onCopyUserID: (userID: string) => Promise<void>;
  onSaveProfile: (userID: string, birthday: string) => Promise<boolean>;
}) {
  const [birthdayDraft, setBirthdayDraft] = useState("");
  const [isBirthdayModalOpen, setIsBirthdayModalOpen] = useState(false);

  useEffect(() => {
    setBirthdayDraft(user?.birthday ?? "");
  }, [user?.id, user?.birthday]);

  if (!user) {
    return <aside className="detail-panel empty-state">选择一个用户查看详情</aside>;
  }

  return (
    <aside className="detail-panel">
      <div className="detail-avatar">{(user.nickname ?? user.email ?? "U").slice(0, 1).toUpperCase()}</div>
      <h3>{user.nickname ?? "未设置昵称"}</h3>
      <p>{user.email ?? "无邮箱"}</p>
      <div className="detail-list">
        <DetailItem label="用户 ID" value={user.id} />
        <DetailItem label="生日" value={formatBirthday(user.birthday)} />
        <DetailItem label="创建时间" value={formatDate(user.created_at)} />
        <DetailItem label="最后登录" value={formatDate(user.last_sign_in_at)} />
        <DetailItem label="匿名用户" value={user.is_anonymous ? "是" : "否"} />
        <DetailItem label="统计记录" value={`${user.stats_record_count ?? 0} 条`} />
        <DetailItem label="当前持仓" value={`${user.holding_count ?? 0} 条`} />
        <DetailItem label="私有表情" value={`${user.private_mood_count ?? 0} 个`} />
      </div>
      <button type="button" className="primary-button full-width" onClick={() => {
        setBirthdayDraft(user.birthday ?? "");
        setIsBirthdayModalOpen(true);
      }}>
        <CalendarDays size={17} />
        {user.birthday ? "修改生日" : "填写生日"}
      </button>
      <button type="button" className="secondary-button full-width" onClick={() => void onCopyUserID(user.id)}>
        <Clipboard size={17} />
        复制用户 ID
      </button>
      {isBirthdayModalOpen && (
        <Modal
          title={user.birthday ? "修改生日" : "填写生日"}
          description={`为 ${user.nickname ?? user.email ?? shortID(user.id)} 设置生日。`}
          dirty={birthdayDraft !== (user.birthday ?? "")}
          isSaving={isSaving}
          onClose={() => setIsBirthdayModalOpen(false)}
          footer={(
            <>
              <button type="button" className="secondary-button" disabled={isSaving} onClick={() => setIsBirthdayModalOpen(false)}>取消</button>
              <button type="button" className="primary-button" disabled={isSaving || birthdayDraft === (user.birthday ?? "")} onClick={async () => {
                if (await onSaveProfile(user.id, birthdayDraft)) setIsBirthdayModalOpen(false);
              }}>
                {isSaving ? <Loader2 className="spin" size={17} /> : <Save size={17} />}
                保存
              </button>
            </>
          )}
        >
          <div className="modal-form">
            <label>
              <span>生日</span>
              <input type="date" value={birthdayDraft} onChange={(event) => setBirthdayDraft(event.target.value)} />
            </label>
            {user.birthday && (
              <button type="button" className="danger-button align-start" disabled={isSaving} onClick={() => setBirthdayDraft("")}>清空生日</button>
            )}
          </div>
        </Modal>
      )}
    </aside>
  );
}

function FullscreenAnimationManagementView({
  animations,
  selectedAnimation,
  draft,
  fixedTriggerType,
  title,
  eyebrow,
  description,
  listDescription,
  isLoading,
  isSaving,
  onDraftChange,
  onRefresh,
  onSelectAnimation,
  onCreate,
  onSave,
  onToggle,
  onReplace,
  onDelete
}: {
  animations: FullscreenAnimation[];
  selectedAnimation: FullscreenAnimation | null;
  draft: FullscreenAnimationDraft;
  fixedTriggerType: FullscreenAnimationTriggerType;
  title: string;
  eyebrow: string;
  description: string;
  listDescription: string;
  isLoading: boolean;
  isSaving: boolean;
  onDraftChange: (draft: FullscreenAnimationDraft) => void;
  onRefresh: () => Promise<void>;
  onSelectAnimation: (animationID: string) => void;
  onCreate: (file: File, triggerType?: FullscreenAnimationTriggerType) => Promise<boolean>;
  onSave: (triggerType?: FullscreenAnimationTriggerType) => Promise<boolean>;
  onToggle: (animationID: string, isEnabled: boolean) => Promise<void>;
  onReplace: (file: File) => Promise<boolean>;
  onDelete: () => Promise<void>;
}) {
  const globalCount = animations.filter((animation) => animation.scope === "global").length;
  const enabledCount = animations.filter((animation) => animation.is_enabled).length;
  const [editorMode, setEditorMode] = useState<"create" | "edit" | "replace" | null>(null);
  const [initialDraft, setInitialDraft] = useState<FullscreenAnimationDraft | null>(null);
  const [file, setFile] = useState<File | null>(null);

  function openAnimationEditor(mode: "create" | "edit" | "replace") {
    if (mode === "create") {
      const next = { name: fixedTriggerType === "birthday_home" ? "Birthday Party" : "Money Stack", scope: "global" as MoodScope, userId: "", triggerType: fixedTriggerType };
      onDraftChange(next);
      setInitialDraft(next);
    } else {
      setInitialDraft({ ...draft });
    }
    setFile(null);
    setEditorMode(mode);
  }

  return (
    <>
      <SectionHeader
        eyebrow={eyebrow}
        title={title}
        description={description}
        action={<>
          <button type="button" className="secondary-button" onClick={() => void onRefresh()} disabled={isLoading}>
            {isLoading ? <Loader2 className="spin" size={17} /> : <RefreshCw size={17} />}
            刷新
          </button>
          <button type="button" className="primary-button" onClick={() => openAnimationEditor("create")} disabled={isSaving}><Plus size={17} />上传动画</button>
        </>}
      />

      <div className="metric-grid">
        <MetricCard label="全部动画" value={animations.length.toString()} />
        <MetricCard label="已启用" value={enabledCount.toString()} />
        <MetricCard label="全局动画" value={globalCount.toString()} />
      </div>

      <section className="mood-workbench">
        <aside className="mode-panel panel">
          <div className="panel-title compact">
            <div>
              <h3>动画列表</h3>
              <p>{listDescription}</p>
            </div>
          </div>

          <div className="mode-list">
            {animations.map((animation) => (
              <button
                key={animation.id}
                type="button"
                className={`mode-row ${selectedAnimation?.id === animation.id ? "selected" : ""}`}
                onClick={() => onSelectAnimation(animation.id)}
              >
                <ScopeIcon scope={animation.scope} />
                <span>
                  <strong>{animation.name}</strong>
                  <small>{fullscreenTriggerLabel(animation.trigger_type)} · {animation.is_enabled ? "已启用" : "已停用"} · {animation.scope === "global" ? "全局可见" : shortID(animation.user_id ?? "")}</small>
                </span>
              </button>
            ))}
            {animations.length === 0 && <div className="empty-state">暂无全屏动画</div>}
          </div>
        </aside>

        <div className="mood-detail">
          <section className="panel">
            <div className="panel-title">
              <div>
                <h3>动画信息</h3>
                <p>查看动画配置；编辑与上传会在弹窗中完成。</p>
              </div>
              <div className="toolbar">{selectedAnimation && <button type="button" className="secondary-button" onClick={() => openAnimationEditor("edit")} disabled={isSaving}><Save size={17} />编辑信息</button>}{selectedAnimation && <button type="button" className="danger-button" onClick={() => void onDelete()} disabled={isSaving}><Trash2 size={17} />删除</button>}</div>
            </div>
            {selectedAnimation ? <><div className="detail-grid"><DetailItem label="动画名称" value={selectedAnimation.name} /><DetailItem label="作用范围" value={selectedAnimation.scope === "global" ? "全局显示" : "指定用户"} /><DetailItem label="触发条件" value={fullscreenTriggerLabel(selectedAnimation.trigger_type)} /><DetailItem label="目标用户 ID" value={selectedAnimation.user_id ?? "无需填写"} /></div><div className="action-row">{
                <button
                  type="button"
                  className="secondary-button"
                  onClick={() => void onToggle(selectedAnimation.id, !selectedAnimation.is_enabled)}
                  disabled={isSaving}
                >
                  <CheckCircle2 size={17} />
                  {selectedAnimation.is_enabled ? "停用" : "启用"}
                </button>
              }</div></> : <div className="empty-state">暂无动画，请点击“上传动画”新增</div>}
          </section>

          <section className="panel">
            <div className="panel-title">
              <div>
                <h3>.lottie 文件</h3>
                <p>{selectedAnimation ? selectedAnimation.storage_path : "创建新动画时选择 .lottie 文件。"}</p>
              </div>
              {selectedAnimation && <StatusPill tone={selectedAnimation.is_enabled ? "success" : "warning"}>{selectedAnimation.is_enabled ? "已启用" : "已停用"}</StatusPill>}
            </div>

            <div className="asset-grid">
              {selectedAnimation && (
                <article className={`asset-card ${selectedAnimation.is_enabled ? "selected" : ""}`}>
                  <div className="gif-frame lottie-frame">
                    <Clapperboard size={36} />
                    <strong>dotLottie</strong>
                  </div>
                  <div className="asset-meta">
                    <strong>{selectedAnimation.name}</strong>
                    <small>{fullscreenTriggerLabel(selectedAnimation.trigger_type)} · {selectedAnimation.storage_path}</small>
                  </div>
                  <div className="card-actions">
                    <button type="button" className="tiny-button" onClick={() => openAnimationEditor("replace")}>
                      <CloudUpload size={15} />
                      替换
                    </button>
                    {selectedAnimation.signed_url && (
                      <a className="tiny-button" href={selectedAnimation.signed_url} target="_blank" rel="noreferrer">预览文件</a>
                    )}
                  </div>
                </article>
              )}
            </div>
          </section>
        </div>
      </section>
      {editorMode && initialDraft && (
        <Modal title={editorMode === "create" ? "上传动画" : editorMode === "edit" ? "编辑动画信息" : "替换动画文件"} description={editorMode === "replace" ? `替换 ${selectedAnimation?.storage_path ?? "当前文件"}` : "配置动画显示范围与目标用户。"} dirty={file !== null || JSON.stringify(draft) !== JSON.stringify(initialDraft)} isSaving={isSaving} onClose={() => setEditorMode(null)} footer={<><button type="button" className="secondary-button" disabled={isSaving} onClick={() => setEditorMode(null)}>取消</button><button type="button" className="primary-button" disabled={isSaving || (editorMode !== "replace" && (!draft.name.trim() || (draft.scope === "user" && !draft.userId.trim()))) || ((editorMode === "create" || editorMode === "replace") && !file)} onClick={async () => { let saved = false; if (editorMode === "create" && file) saved = await onCreate(file, fixedTriggerType); else if (editorMode === "edit") saved = await onSave(fixedTriggerType); else if (editorMode === "replace" && file) saved = await onReplace(file); if (saved) setEditorMode(null); }}>{isSaving ? <Loader2 className="spin" size={17} /> : <Save size={17} />}{editorMode === "edit" ? "保存修改" : "上传并保存"}</button></>}>
          {editorMode !== "replace" && <div className="modal-form form-grid"><label><span>动画名称</span><input value={draft.name} maxLength={32} onChange={(event) => onDraftChange({ ...draft, name: event.target.value })} /></label><label><span>作用范围</span><select value={draft.scope} onChange={(event) => onDraftChange({ ...draft, scope: event.target.value as MoodScope, userId: event.target.value === "global" ? "" : draft.userId })}><option value="global">全局显示</option><option value="user">指定用户</option></select></label><label><span>触发条件</span><input value={fullscreenTriggerLabel(fixedTriggerType)} disabled /></label><label><span>目标用户 ID</span><input value={draft.userId} disabled={draft.scope === "global"} placeholder={draft.scope === "global" ? "全局动画无需填写" : "粘贴 Supabase 用户 ID"} onChange={(event) => onDraftChange({ ...draft, userId: event.target.value })} /></label></div>}
          {(editorMode === "create" || editorMode === "replace") && <FilePicker accept=".lottie" hint="标准 .lottie 文件，服务器限制 8 MB" file={file} onFileChange={setFile} />}
        </Modal>
      )}
    </>
  );
}

function ExtremeDayMessageManagementView({
  messages,
  selectedMessage,
  draft,
  isLoading,
  isSaving,
  onDraftChange,
  onRefresh,
  onSelectMessage,
  onCreate,
  onSave,
  onToggle,
  onDelete
}: {
  messages: ExtremeDayMessage[];
  selectedMessage: ExtremeDayMessage | null;
  draft: ExtremeDayMessageDraft;
  isLoading: boolean;
  isSaving: boolean;
  onDraftChange: (draft: ExtremeDayMessageDraft) => void;
  onRefresh: () => Promise<void>;
  onSelectMessage: (messageID: string) => void;
  onCreate: () => Promise<boolean>;
  onSave: () => Promise<boolean>;
  onToggle: (messageID: string, isEnabled: boolean) => Promise<void>;
  onDelete: () => Promise<void>;
}) {
  const streakCount = messages.filter((item) => item.trigger_type === "consecutive_profit" || item.trigger_type === "consecutive_loss").length;
  const transitionCount = messages.filter((item) => item.trigger_type === "loss_to_profit" || item.trigger_type === "profit_to_loss").length;
  const enabledCount = messages.filter((item) => item.is_enabled).length;
  const [editorMode, setEditorMode] = useState<"create" | "edit" | null>(null);
  const [initialDraft, setInitialDraft] = useState<ExtremeDayMessageDraft | null>(null);
  const [selectedTrigger, setSelectedTrigger] = useState<ExtremeDayTriggerType>(selectedMessage?.trigger_type ?? "consecutive_loss");
  const triggerTypes: ExtremeDayTriggerType[] = ["consecutive_loss", "consecutive_profit", "loss_to_profit", "profit_to_loss"];
  const categoryMessages = messages.filter((item) => item.trigger_type === selectedTrigger);
  const activeMessage = selectedMessage?.trigger_type === selectedTrigger ? selectedMessage : categoryMessages[0] ?? null;

  function selectTrigger(trigger: ExtremeDayTriggerType) {
    setSelectedTrigger(trigger);
    const firstMessage = messages.find((item) => item.trigger_type === trigger);
    if (firstMessage) onSelectMessage(firstMessage.id);
  }

  function openMessageEditor(mode: "create" | "edit") {
    const next = mode === "create" ? { scope: "global" as MoodScope, userId: "", triggerType: selectedTrigger, message: "", sortOrder: 0 } : { ...draft };
    onDraftChange(next);
    setInitialDraft(next);
    setEditorMode(mode);
  }

  return (
    <>
      <SectionHeader
        eyebrow="Copywriting"
        title="趋势文案"
        description="维护连续盈亏与行情反转四类随机短句，App 会按最近结算状态自动展示。"
        action={
          <div className="toolbar">
            <button type="button" className="secondary-button" onClick={() => void onRefresh()} disabled={isLoading}>
              {isLoading ? <Loader2 className="spin" size={17} /> : <RefreshCw size={17} />}
              刷新
            </button>
            <button type="button" className="primary-button" onClick={() => openMessageEditor("create")} disabled={isSaving}>
              <Plus size={17} />
              新增文案
            </button>
          </div>
        }
      />

      <div className="metric-grid">
        <MetricCard label="全部文案" value={messages.length.toString()} />
        <MetricCard label="已启用" value={enabledCount.toString()} />
        <MetricCard label="连续/反转" value={`${streakCount}/${transitionCount}`} />
      </div>

      <section className="mood-workbench">
        <aside className="mode-panel panel">
          <div className="panel-title compact">
            <div>
              <h3>文案分类</h3>
              <p>选择分类后在右侧管理文案。</p>
            </div>
          </div>

          <div className="mode-list">
            {triggerTypes.map((trigger) => {
              const count = messages.filter((item) => item.trigger_type === trigger).length;
              const activeCount = messages.filter((item) => item.trigger_type === trigger && item.is_enabled).length;
              return (
              <button
                key={trigger}
                type="button"
                className={`mode-row ${selectedTrigger === trigger ? "selected" : ""}`}
                onClick={() => selectTrigger(trigger)}
              >
                <MessageSquareQuote size={18} />
                <span>
                  <strong>{triggerLabel(trigger)}</strong>
                  <small>{count} 条文案 · {activeCount} 条启用</small>
                </span>
              </button>
              );
            })}
          </div>
        </aside>

        <div className="mood-detail">
          <section className="panel trend-category-detail">
            <div className="panel-title">
              <div><h3>{triggerLabel(selectedTrigger)}</h3><p>选择一条文案查看详情；启用的文案会在 App 中随机展示。</p></div>
              <button type="button" className="primary-button" onClick={() => openMessageEditor("create")} disabled={isSaving}><Plus size={17} />新增此分类文案</button>
            </div>
            <div className="table-wrap">
              <table className="data-table trend-message-table">
                <thead><tr><th>文案</th><th>范围</th><th>排序</th><th>状态</th></tr></thead>
                <tbody>{categoryMessages.map((item) => <tr key={item.id} className={activeMessage?.id === item.id ? "selected-row" : ""} onClick={() => onSelectMessage(item.id)}><td><strong>{item.message}</strong></td><td>{item.scope === "global" ? "全局" : "指定用户"}</td><td>{item.sort_order}</td><td><StatusPill tone={item.is_enabled ? "success" : "warning"}>{item.is_enabled ? "已启用" : "已停用"}</StatusPill></td></tr>)}</tbody>
              </table>
              {categoryMessages.length === 0 && <div className="empty-state">该分类暂无文案，点击“新增此分类文案”开始添加</div>}
            </div>
          </section>

          <section className="panel">
            <div className="panel-title">
              <div>
                <h3>文案详情</h3>
                <p>查看当前文案配置；填写与修改会在弹窗中完成。</p>
              </div>
              <div className="toolbar">{activeMessage && <button type="button" className="secondary-button" onClick={() => openMessageEditor("edit")} disabled={isSaving}><Save size={17} />编辑文案</button>}{activeMessage && <button type="button" className="danger-button" onClick={() => void onDelete()} disabled={isSaving}><Trash2 size={17} />删除</button>}</div>
            </div>
            {activeMessage ? <><div className="detail-grid"><DetailItem label="触发类型" value={triggerLabel(activeMessage.trigger_type)} /><DetailItem label="作用范围" value={activeMessage.scope === "global" ? "全局显示" : "指定用户"} /><DetailItem label="排序" value={String(activeMessage.sort_order)} /><DetailItem label="目标用户 ID" value={activeMessage.user_id ?? "无需填写"} /></div><div className="readonly-copy"><span>文案内容</span><strong>{activeMessage.message}</strong></div><div className="action-row">{
                <button
                  type="button"
                  className="secondary-button"
                  onClick={() => void onToggle(activeMessage.id, !activeMessage.is_enabled)}
                  disabled={isSaving}
                >
                  <CheckCircle2 size={17} />
                  {activeMessage.is_enabled ? "停用" : "启用"}
                </button>
              }</div></> : <div className="empty-state">暂无文案，请点击“新增文案”填写</div>}
          </section>

          <section className="panel">
            <div className="panel-title compact">
              <div>
                <h3>展示预览</h3>
              <p>{activeMessage ? triggerLabel(activeMessage.trigger_type) : "选择文案查看效果"}</p>
              </div>
            </div>
            <div className={`copy-preview ${activeMessage?.trigger_type === "consecutive_loss" || activeMessage?.trigger_type === "profit_to_loss" ? "loss" : ""}`}>
              <MessageSquareQuote size={20} />
              <strong>{activeMessage?.message ?? "暂无趋势短句"}</strong>
              <span>{triggerLabel(activeMessage?.trigger_type ?? selectedTrigger)} · {activeMessage?.scope === "user" ? "指定用户" : "全局"}</span>
            </div>
          </section>
        </div>
      </section>
      {editorMode && initialDraft && <Modal title={editorMode === "create" ? "新增文案" : "编辑文案"} description="建议 8-32 个字，最多 80 个字。" dirty={JSON.stringify(draft) !== JSON.stringify(initialDraft)} isSaving={isSaving} onClose={() => setEditorMode(null)} footer={<><button type="button" className="secondary-button" disabled={isSaving} onClick={() => setEditorMode(null)}>取消</button><button type="button" className="primary-button" disabled={isSaving || !draft.message.trim() || draft.message.trim().length > 80 || draft.sortOrder < 0 || draft.sortOrder > 999 || (draft.scope === "user" && !draft.userId.trim())} onClick={async () => { const saved = editorMode === "create" ? await onCreate() : await onSave(); if (saved) setEditorMode(null); }}>{isSaving ? <Loader2 className="spin" size={17} /> : <Save size={17} />}{editorMode === "create" ? "新增并保存" : "保存修改"}</button></>}><div className="modal-form form-grid"><label><span>触发类型</span><select value={draft.triggerType} onChange={(event) => onDraftChange({ ...draft, triggerType: event.target.value as ExtremeDayTriggerType })}><option value="consecutive_loss">连续亏损</option><option value="consecutive_profit">连续盈利</option><option value="loss_to_profit">转危为安</option><option value="profit_to_loss">风云突变</option></select></label><label><span>作用范围</span><select value={draft.scope} onChange={(event) => onDraftChange({ ...draft, scope: event.target.value as MoodScope, userId: event.target.value === "global" ? "" : draft.userId })}><option value="global">全局显示</option><option value="user">指定用户</option></select></label><label><span>排序</span><input type="number" min={0} max={999} value={draft.sortOrder} onChange={(event) => onDraftChange({ ...draft, sortOrder: Number(event.target.value) })} /></label><label><span>目标用户 ID</span><input value={draft.userId} disabled={draft.scope === "global"} placeholder={draft.scope === "global" ? "全局文案无需填写" : "粘贴 Supabase 用户 ID"} onChange={(event) => onDraftChange({ ...draft, userId: event.target.value })} /></label><label className="wide-field"><span>文案内容</span><textarea value={draft.message} maxLength={80} rows={4} placeholder="例如：阳线改变信仰，属于你的主场回来了！" onChange={(event) => onDraftChange({ ...draft, message: event.target.value })} /><small>{draft.message.trim().length}/80</small></label></div></Modal>}
    </>
  );
}

function MoodManagementView({
  modes,
  filteredModes,
  selectedMode,
  draft,
  filter,
  isLoading,
  isSaving,
  onDraftChange,
  onFilterChange,
  onRefresh,
  onCreateMode,
  onSaveMode,
  onDeleteMode,
  onSelectMode,
  onUpload,
  onReplace,
  onSelectAsset,
  onDeleteAsset
}: {
  modes: MoodMode[];
  filteredModes: MoodMode[];
  selectedMode: MoodMode | null;
  draft: ModeDraft;
  filter: "all" | MoodScope;
  isLoading: boolean;
  isSaving: boolean;
  onDraftChange: (draft: ModeDraft) => void;
  onFilterChange: (filter: "all" | MoodScope) => void;
  onRefresh: () => Promise<void>;
  onCreateMode: () => Promise<boolean>;
  onSaveMode: () => Promise<boolean>;
  onDeleteMode: () => Promise<void>;
  onSelectMode: (modeID: string) => void;
  onUpload: (kind: AssetKind, file: File) => Promise<boolean>;
  onReplace: (assetID: string, file: File) => Promise<boolean>;
  onSelectAsset: (assetID: string) => Promise<void>;
  onDeleteAsset: (assetID: string) => Promise<void>;
}) {
  const globalModes = modes.filter((mode) => mode.scope === "global").length;
  const userModes = modes.filter((mode) => mode.scope === "user").length;
  const [editorMode, setEditorMode] = useState<"create" | "edit" | null>(null);
  const [initialDraft, setInitialDraft] = useState<ModeDraft | null>(null);

  function openModeEditor(mode: "create" | "edit") {
    const nextDraft = mode === "create"
      ? { name: "", scope: "global" as MoodScope, userId: "", behavior: "random" as MoodBehavior }
      : { ...draft };
    onDraftChange(nextDraft);
    setInitialDraft(nextDraft);
    setEditorMode(mode);
  }

  return (
    <>
      <SectionHeader
        eyebrow="Moods"
        title="表情管理"
        description="维护统计面板 GIF 表情包，支持全局和指定用户可见。"
        action={
          <div className="toolbar">
            <button type="button" className="secondary-button" onClick={() => void onRefresh()} disabled={isLoading}>
              {isLoading ? <Loader2 className="spin" size={17} /> : <RefreshCw size={17} />}
              刷新
            </button>
            <button type="button" className="primary-button" onClick={() => openModeEditor("create")} disabled={isSaving}>
              <Plus size={17} />
              新建模式
            </button>
          </div>
        }
      />

      <div className="metric-grid">
        <MetricCard label="全部模式" value={modes.length.toString()} />
        <MetricCard label="全局模式" value={globalModes.toString()} />
        <MetricCard label="用户模式" value={userModes.toString()} />
      </div>

      <section className="mood-workbench">
        <aside className="mode-panel panel">
          <div className="panel-title compact">
            <div>
              <h3>模式列表</h3>
              <p>选择后编辑详情和 GIF。</p>
            </div>
          </div>

          <div className="segmented">
            {(["all", "global", "user"] as const).map((item) => (
              <button
                key={item}
                type="button"
                className={filter === item ? "active" : ""}
                onClick={() => onFilterChange(item)}
              >
                {item === "all" ? "全部" : item === "global" ? "全局" : "用户"}
              </button>
            ))}
          </div>

          <div className="mode-list">
            {filteredModes.map((mode) => (
              <button
                key={mode.id}
                type="button"
                className={`mode-row ${selectedMode?.id === mode.id ? "selected" : ""}`}
                onClick={() => onSelectMode(mode.id)}
              >
                <ScopeIcon scope={mode.scope} />
                <span>
                  <strong>{mode.name}</strong>
                  <small>{mode.scope === "global" ? "全局可见" : mode.user_id}</small>
                </span>
              </button>
            ))}
            {filteredModes.length === 0 && <div className="empty-state">暂无表情模式</div>}
          </div>
        </aside>

        <div className="mood-detail">
          <section className="panel">
            <div className="panel-title">
              <div>
                <h3>模式信息</h3>
                <p>查看当前模式配置；修改操作会在弹窗中完成。</p>
              </div>
              <div className="toolbar">
                {selectedMode && <button type="button" className="secondary-button" onClick={() => openModeEditor("edit")} disabled={isSaving}><Save size={17} />编辑模式</button>}
                {selectedMode && <button type="button" className="danger-button" onClick={() => void onDeleteMode()} disabled={isSaving}><Trash2 size={17} />删除</button>}
              </div>
            </div>
            {selectedMode ? <div className="detail-grid"><DetailItem label="模式名称" value={selectedMode.name} /><DetailItem label="作用范围" value={selectedMode.scope === "global" ? "全局显示" : "指定用户"} /><DetailItem label="玩法" value={selectedMode.behavior === "random" ? "随机" : "手动"} /><DetailItem label="目标用户 ID" value={selectedMode.user_id ?? "无需填写"} /></div> : <div className="empty-state">请选择一个模式查看详情</div>}
          </section>

          {selectedMode && (
            <section className="asset-layout">
              <AssetSection title="默认表情" kind="default" mode={selectedMode} selectedAssetID={null} isSaving={isSaving} onUpload={onUpload} onReplace={onReplace} onSelect={onSelectAsset} onDelete={onDeleteAsset} />
              <AssetSection title="盈利表情" kind="profit" mode={selectedMode} selectedAssetID={selectedMode.selected_profit_asset_id} isSaving={isSaving} onUpload={onUpload} onReplace={onReplace} onSelect={onSelectAsset} onDelete={onDeleteAsset} />
              <AssetSection title="亏损表情" kind="loss" mode={selectedMode} selectedAssetID={selectedMode.selected_loss_asset_id} isSaving={isSaving} onUpload={onUpload} onReplace={onReplace} onSelect={onSelectAsset} onDelete={onDeleteAsset} />
            </section>
          )}
        </div>
      </section>
      {editorMode && initialDraft && (
        <Modal
          title={editorMode === "create" ? "新建模式" : "编辑模式"}
          description="填写全局或指定用户可见的 GIF 表情模式配置。"
          dirty={JSON.stringify(draft) !== JSON.stringify(initialDraft)}
          isSaving={isSaving}
          onClose={() => setEditorMode(null)}
          footer={<><button type="button" className="secondary-button" disabled={isSaving} onClick={() => setEditorMode(null)}>取消</button><button type="button" className="primary-button" disabled={isSaving || !draft.name.trim() || (draft.scope === "user" && !draft.userId.trim())} onClick={async () => { const saved = editorMode === "create" ? await onCreateMode() : await onSaveMode(); if (saved) setEditorMode(null); }}>{isSaving ? <Loader2 className="spin" size={17} /> : <Save size={17} />}{editorMode === "create" ? "创建并保存" : "保存修改"}</button></>}
        >
          <div className="modal-form form-grid">
            <label><span>模式名称</span><input value={draft.name} maxLength={16} onChange={(event) => onDraftChange({ ...draft, name: event.target.value })} /></label>
            <label><span>作用范围</span><select value={draft.scope} onChange={(event) => onDraftChange({ ...draft, scope: event.target.value as MoodScope, userId: event.target.value === "global" ? "" : draft.userId })}><option value="global">全局显示</option><option value="user">指定用户</option></select></label>
            <label><span>玩法</span><select value={draft.behavior} onChange={(event) => onDraftChange({ ...draft, behavior: event.target.value as MoodBehavior })}><option value="random">随机</option><option value="manual">手动</option></select></label>
            <label><span>目标用户 ID</span><input value={draft.userId} disabled={draft.scope === "global"} placeholder={draft.scope === "global" ? "全局模式无需填写" : "粘贴 Supabase 用户 ID"} onChange={(event) => onDraftChange({ ...draft, userId: event.target.value })} /></label>
          </div>
        </Modal>
      )}
    </>
  );
}

function AssetSection({
  title,
  kind,
  mode,
  selectedAssetID,
  isSaving,
  onUpload,
  onReplace,
  onSelect,
  onDelete
}: {
  title: string;
  kind: AssetKind;
  mode: MoodMode;
  selectedAssetID: string | null;
  isSaving: boolean;
  onUpload: (kind: AssetKind, file: File) => Promise<boolean>;
  onReplace: (assetID: string, file: File) => Promise<boolean>;
  onSelect: (assetID: string) => Promise<void>;
  onDelete: (assetID: string) => Promise<void>;
}) {
  const assets = useMemo(
    () => mode.assets.filter((asset) => asset.kind === kind).sort((a, b) => a.sort_order - b.sort_order),
    [mode.assets, kind]
  );
  const canUpload = kind === "default" ? assets.length === 0 : assets.length < 5;
  const [fileAction, setFileAction] = useState<{ type: "upload" | "replace"; asset?: MoodAsset } | null>(null);
  const [file, setFile] = useState<File | null>(null);

  function openFileModal(action: { type: "upload" | "replace"; asset?: MoodAsset }) {
    setFile(null);
    setFileAction(action);
  }

  return (
    <section className="panel">
      <div className="panel-title compact">
        <div>
          <h3>{title}</h3>
          <p>{kind === "default" ? "最多 1 张" : `${assets.length}/5 张`}</p>
        </div>
      </div>

      <div className="asset-grid">
        {assets.map((asset) => (
          <AssetCard
            key={asset.id}
            asset={asset}
            selected={selectedAssetID === asset.id}
            selectable={kind !== "default"}
            onRequestReplace={() => openFileModal({ type: "replace", asset })}
            onSelect={onSelect}
            onDelete={onDelete}
          />
        ))}
        {canUpload && <button type="button" className="drop-zone" onClick={() => openFileModal({ type: "upload" })}><CloudUpload size={24} /><strong>上传 GIF</strong><span>在弹窗中选择文件并确认保存</span></button>}
      </div>
      {fileAction && (
        <Modal
          title={fileAction.type === "upload" ? `上传${title}` : "替换 GIF"}
          description={fileAction.type === "upload" ? `${kind === "default" ? "最多 1 张" : "盈利/亏损 GIF 最多 5 张"}，仅支持 GIF 文件。` : `替换 ${fileAction.asset?.storage_path ?? "当前文件"}。`}
          dirty={file !== null}
          isSaving={isSaving}
          onClose={() => setFileAction(null)}
          footer={<><button type="button" className="secondary-button" disabled={isSaving} onClick={() => setFileAction(null)}>取消</button><button type="button" className="primary-button" disabled={!file || isSaving} onClick={async () => { if (!file) return; const saved = fileAction.type === "upload" ? await onUpload(kind, file) : await onReplace(fileAction.asset!.id, file); if (saved) setFileAction(null); }}>{isSaving ? <Loader2 className="spin" size={17} /> : <CloudUpload size={17} />}上传并保存</button></>}
        >
          <FilePicker accept="image/gif" hint="GIF 文件，服务器限制 8 MB" file={file} onFileChange={setFile} />
        </Modal>
      )}
    </section>
  );
}

function AssetCard({
  asset,
  selected,
  selectable,
  onRequestReplace,
  onSelect,
  onDelete
}: {
  asset: MoodAsset;
  selected: boolean;
  selectable: boolean;
  onRequestReplace: () => void;
  onSelect: (assetID: string) => Promise<void>;
  onDelete: (assetID: string) => Promise<void>;
}) {
  return (
    <article className={`asset-card ${selected ? "selected" : ""}`}>
      <div className="gif-frame">
        {asset.signed_url ? <img src={asset.signed_url} alt="GIF 预览" /> : <ImagePlus size={28} />}
      </div>
      <div className="asset-meta">
        <strong>{asset.kind === "default" ? "默认" : `${asset.kind === "profit" ? "盈利" : "亏损"} ${asset.sort_order + 1}`}</strong>
        <small>{asset.storage_path}</small>
      </div>
      <div className="card-actions">
        {selectable && (
          <button type="button" className="tiny-button" onClick={() => void onSelect(asset.id)}>
            <CheckCircle2 size={15} />
            {selected ? "已选" : "设为手动"}
          </button>
        )}
        <button type="button" className="tiny-button" onClick={onRequestReplace}>
          <CloudUpload size={15} />
          替换
        </button>
        <button type="button" className="tiny-button danger" onClick={() => void onDelete(asset.id)}>
          <Trash2 size={15} />
          删除
        </button>
      </div>
    </article>
  );
}

function DropUpload({ kind, onUpload }: { kind: AssetKind; onUpload: (kind: AssetKind, file: File) => Promise<void> }) {
  const [isDragOver, setIsDragOver] = useState(false);

  function handleFile(file: File | undefined) {
    if (!file) return;
    void onUpload(kind, file);
  }

  return (
    <label
      className={`drop-zone ${isDragOver ? "dragging" : ""}`}
      onDragOver={(event) => {
        event.preventDefault();
        setIsDragOver(true);
      }}
      onDragLeave={() => setIsDragOver(false)}
      onDrop={(event) => {
        event.preventDefault();
        setIsDragOver(false);
        handleFile(event.dataTransfer.files[0]);
      }}
    >
      <CloudUpload size={24} />
      <strong>上传 GIF</strong>
      <span>拖拽文件到这里，或点击选择</span>
      <input type="file" accept="image/gif" onChange={(event) => handleFile(event.target.files?.[0])} />
    </label>
  );
}

function FullscreenAnimationDropUpload({ onUpload, disabled }: { onUpload: (file: File) => Promise<void>; disabled: boolean }) {
  const [isDragOver, setIsDragOver] = useState(false);

  function handleFile(file: File | undefined) {
    if (!file || disabled) return;
    void onUpload(file);
  }

  return (
    <label
      className={`drop-zone ${isDragOver ? "dragging" : ""}`}
      onDragOver={(event) => {
        event.preventDefault();
        setIsDragOver(true);
      }}
      onDragLeave={() => setIsDragOver(false)}
      onDrop={(event) => {
        event.preventDefault();
        setIsDragOver(false);
        handleFile(event.dataTransfer.files[0]);
      }}
    >
      <Clapperboard size={24} />
      <strong>上传 .lottie</strong>
      <span>拖拽 Money Stack.lottie 到这里，或点击选择</span>
      <input type="file" accept=".lottie" disabled={disabled} onChange={(event) => handleFile(event.target.files?.[0])} />
    </label>
  );
}

function FilePicker({ accept, hint, file, onFileChange }: { accept: string; hint: string; file: File | null; onFileChange: (file: File | null) => void }) {
  return (
    <div className="file-picker">
      <label>
        <CloudUpload size={26} />
        <strong>{file ? "重新选择文件" : "选择文件"}</strong>
        <span>{hint}</span>
        <input type="file" accept={accept} onChange={(event) => onFileChange(event.target.files?.[0] ?? null)} />
      </label>
      {file && <div className="selected-file"><strong>{file.name}</strong><span>{formatFileSize(file.size)}</span></div>}
    </div>
  );
}

function Modal({
  title,
  description,
  dirty,
  isSaving,
  onClose,
  children,
  footer
}: {
  title: string;
  description?: string;
  dirty: boolean;
  isSaving: boolean;
  onClose: () => void;
  children: React.ReactNode;
  footer: React.ReactNode;
}) {
  const dialogRef = useRef<HTMLDivElement>(null);
  const returnFocusRef = useRef<HTMLElement | null>(document.activeElement as HTMLElement | null);
  const dirtyRef = useRef(dirty);
  const savingRef = useRef(isSaving);
  const titleID = useMemo(() => `modal-title-${Math.random().toString(36).slice(2)}`, []);
  dirtyRef.current = dirty;
  savingRef.current = isSaving;

  function requestClose() {
    if (savingRef.current) return;
    if (dirtyRef.current && !window.confirm("有尚未保存的修改，确定关闭吗？")) return;
    onClose();
  }

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const dialog = dialogRef.current;
    const focusable = dialog?.querySelector<HTMLElement>(
      "input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), a[href]"
    );
    focusable?.focus();

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        requestClose();
        return;
      }
      if (event.key !== "Tab" || !dialog) return;
      const items = Array.from(dialog.querySelectorAll<HTMLElement>(
        "input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), a[href]"
      ));
      if (items.length === 0) return;
      const first = items[0];
      const last = items[items.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }

    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener("keydown", onKeyDown);
      returnFocusRef.current?.focus();
    };
  }, []);

  return (
    <div className="modal-backdrop" onMouseDown={(event) => {
      if (event.target === event.currentTarget) requestClose();
    }}>
      <div ref={dialogRef} className="modal-dialog" role="dialog" aria-modal="true" aria-labelledby={titleID}>
        <header className="modal-header">
          <div>
            <h2 id={titleID}>{title}</h2>
            {description && <p>{description}</p>}
          </div>
          <button type="button" className="icon-button" aria-label="关闭弹窗" onClick={requestClose} disabled={isSaving}>
            <X size={19} />
          </button>
        </header>
        <div className="modal-body">{children}</div>
        <footer className="modal-footer" onClickCapture={(event) => {
          const button = (event.target as HTMLElement).closest("button");
          if (button?.textContent?.trim() !== "取消" || !dirtyRef.current) return;
          if (!window.confirm("有尚未保存的修改，确定关闭吗？")) {
            event.preventDefault();
            event.stopPropagation();
          }
        }}>{footer}</footer>
      </div>
    </div>
  );
}

function SectionHeader({ eyebrow, title, description, action }: { eyebrow: string; title: string; description: string; action: React.ReactNode }) {
  return (
    <header className="topbar">
      <div>
        <p className="eyebrow">{eyebrow}</p>
        <h2>{title}</h2>
        <p>{description}</p>
      </div>
      <div className="toolbar">{action}</div>
    </header>
  );
}

function MetricCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="metric-card">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function DetailItem({ label, value }: { label: string; value: string }) {
  return (
    <div className="detail-item">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function ScopeIcon({ scope }: { scope: MoodScope }) {
  return scope === "global" ? <Globe2 size={18} /> : <UserRoundCheck size={18} />;
}

function StatusPill({ tone, children }: { tone: "success" | "warning"; children: React.ReactNode }) {
  return <span className={`status-pill ${tone}`}>{children}</span>;
}

function StatusMessage({ message }: { message: { type: "success" | "error"; text: string } }) {
  return (
    <div className={`status ${message.type}`} role="status" aria-live="polite">
      {message.type === "success" ? <CheckCircle2 size={18} /> : <XCircle size={18} />}
      {message.text}
    </div>
  );
}

function triggerLabel(triggerType: ExtremeDayTriggerType): string {
  switch (triggerType) {
    case "consecutive_loss": return "连续亏损";
    case "consecutive_profit": return "连续盈利";
    case "loss_to_profit": return "转危为安";
    case "profit_to_loss": return "风云突变";
  }
}

function fullscreenTriggerLabel(triggerType: FullscreenAnimationTriggerType): string {
  return triggerType === "birthday_home" ? "生日首页" : "最大盈利日";
}

function shortID(id: string): string {
  return `${id.slice(0, 8)}...${id.slice(-6)}`;
}

function formatBirthday(value: string | null): string {
  if (!value) return "未填写";
  return value.slice(5).replace("-", "月") + "日";
}

function formatDate(value: string | null): string {
  if (!value) return "暂无";
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

function formatUSD(value: number): string {
  return new Intl.NumberFormat("zh-CN", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 2
  }).format(value);
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}


createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
