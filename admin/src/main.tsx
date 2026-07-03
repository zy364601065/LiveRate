import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  CheckCircle2,
  Clipboard,
  CloudUpload,
  Database,
  Globe2,
  ImagePlus,
  LayoutDashboard,
  Loader2,
  Lock,
  Plus,
  RefreshCw,
  Save,
  Search,
  Sparkles,
  Trash2,
  UserRoundCheck,
  UsersRound,
  XCircle
} from "lucide-react";
import "./styles.css";

type SectionKey = "users" | "records" | "moods";
type MoodScope = "global" | "user";
type MoodBehavior = "random" | "manual";
type AssetKind = "default" | "profit" | "loss";

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
  created_at: string | null;
  last_sign_in_at: string | null;
  is_anonymous: boolean;
  profile_status: "synced" | "missing";
  stats_record_count?: number;
  private_mood_count?: number;
};

type StatUploadRecord = {
  id: string;
  user_id: string;
  nickname: string | null;
  timestamp: string;
  usd_amount: number;
};

type ModeDraft = {
  name: string;
  scope: MoodScope;
  userId: string;
  behavior: MoodBehavior;
};

const passwordStorageKey = "myliverate.mood_admin.password";

function App() {
  const [password, setPassword] = useState(() => localStorage.getItem(passwordStorageKey) ?? "");
  const [passwordInput, setPasswordInput] = useState("");
  const [activeSection, setActiveSection] = useState<SectionKey>("users");
  const [modes, setModes] = useState<MoodMode[]>([]);
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [uploadRecords, setUploadRecords] = useState<StatUploadRecord[]>([]);
  const [selectedModeID, setSelectedModeID] = useState<string>("");
  const [selectedUserID, setSelectedUserID] = useState<string>("");
  const [selectedUserDetail, setSelectedUserDetail] = useState<AdminUser | null>(null);
  const [draft, setDraft] = useState<ModeDraft>({ name: "", scope: "global", userId: "", behavior: "random" });
  const [moodFilter, setMoodFilter] = useState<"all" | MoodScope>("all");
  const [userSearch, setUserSearch] = useState("");
  const [recordSearch, setRecordSearch] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const selectedMode = modes.find((mode) => mode.id === selectedModeID) ?? modes[0] ?? null;
  const filteredModes = modes.filter((mode) => moodFilter === "all" || mode.scope === moodFilter);
  const filteredUsers = useMemo(() => {
    const keyword = userSearch.trim().toLowerCase();
    if (!keyword) return users;
    return users.filter((user) =>
      user.id.toLowerCase().includes(keyword)
      || (user.email ?? "").toLowerCase().includes(keyword)
      || (user.nickname ?? "").toLowerCase().includes(keyword)
    );
  }, [users, userSearch]);
  const filteredUploadRecords = useMemo(() => {
    const keyword = recordSearch.trim().toLowerCase();
    if (!keyword) return uploadRecords;
    return uploadRecords.filter((record) =>
      record.id.toLowerCase().includes(keyword)
      || record.user_id.toLowerCase().includes(keyword)
      || (record.nickname ?? "").toLowerCase().includes(keyword)
    );
  }, [uploadRecords, recordSearch]);

  useEffect(() => {
    if (!password) return;
    void loadUsers();
    void loadUploadRecords();
    void loadModes();
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
        setSelectedUserID(payload.users[0].id);
        setSelectedUserDetail(payload.users[0]);
      }
    } catch (error) {
      showError(error);
    } finally {
      setIsLoading(false);
    }
  }

  async function loadUserDetail(userID: string) {
    setSelectedUserID(userID);
    setSelectedUserDetail(users.find((user) => user.id === userID) ?? null);
    setMessage(null);
    try {
      const payload = await api<{ user: AdminUser }>(`/api/users/${userID}`);
      setSelectedUserDetail(payload.user);
    } catch (error) {
      showError(error);
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
    } catch (error) {
      showError(error);
    } finally {
      setIsSaving(false);
    }
  }

  async function saveMode() {
    if (!selectedMode) return;
    setIsSaving(true);
    setMessage(null);
    try {
      await api(`/api/modes/${selectedMode.id}`, {
        method: "PATCH",
        body: JSON.stringify(draft)
      });
      await loadModes();
      setMessage({ type: "success", text: "模式已保存" });
    } catch (error) {
      showError(error);
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
    if (!selectedMode) return;
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
    } catch (error) {
      showError(error);
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
    } catch (error) {
      showError(error);
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
  }

  function showError(error: unknown) {
    setMessage({ type: "error", text: error instanceof Error ? error.message : "操作失败" });
  }

  if (!password) {
    return (
      <main className="login-shell">
        <form className="login-panel" onSubmit={login}>
          <div className="login-icon"><LayoutDashboard size={22} /></div>
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
          <div>
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
            className={activeSection === "records" ? "active" : ""}
            onClick={() => setActiveSection("records")}
          >
            <Database size={18} />
            <span>
              <strong>上传记录</strong>
              <small>{uploadRecords.length} 条记录</small>
            </span>
          </button>
        </nav>

        <button className="ghost-button" type="button" onClick={logout}>退出后台</button>
      </aside>

      <section className="workspace">
        {message && <StatusMessage message={message} />}

        {activeSection === "users" ? (
          <UserManagementView
            users={filteredUsers}
            allUsers={users}
            search={userSearch}
            selectedUserID={selectedUserID}
            selectedUserDetail={selectedUserDetail}
            isLoading={isLoading}
            onSearchChange={setUserSearch}
            onRefresh={loadUsers}
            onSelectUser={loadUserDetail}
            onCopyUserID={copyUserID}
          />
        ) : activeSection === "records" ? (
          <UploadRecordsView
            records={filteredUploadRecords}
            allRecords={uploadRecords}
            search={recordSearch}
            isLoading={isLoading}
            onSearchChange={setRecordSearch}
            onRefresh={loadUploadRecords}
            onCopyUserID={copyUserID}
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

function UserManagementView({
  users,
  allUsers,
  search,
  selectedUserID,
  selectedUserDetail,
  isLoading,
  onSearchChange,
  onRefresh,
  onSelectUser,
  onCopyUserID
}: {
  users: AdminUser[];
  allUsers: AdminUser[];
  search: string;
  selectedUserID: string;
  selectedUserDetail: AdminUser | null;
  isLoading: boolean;
  onSearchChange: (value: string) => void;
  onRefresh: () => Promise<void>;
  onSelectUser: (userID: string) => Promise<void>;
  onCopyUserID: (userID: string) => Promise<void>;
}) {
  const syncedProfiles = allUsers.filter((user) => user.profile_status === "synced").length;
  const anonymousUsers = allUsers.filter((user) => user.is_anonymous).length;

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
        <MetricCard label="匿名用户" value={anonymousUsers.toString()} />
      </div>

      <section className="panel">
        <div className="panel-title">
          <div>
            <h3>用户列表</h3>
            <p>搜索邮箱、昵称或用户 ID，复制后可用于指定用户表情包。</p>
          </div>
          <label className="search-field">
            <Search size={17} />
            <input
              value={search}
              onChange={(event) => onSearchChange(event.target.value)}
              placeholder="搜索用户 ID / 邮箱 / 昵称"
            />
          </label>
        </div>

        <div className="split-grid">
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>用户</th>
                  <th>邮箱</th>
                  <th>资料</th>
                  <th>最后登录</th>
                  <th>操作</th>
                </tr>
              </thead>
              <tbody>
                {users.map((user) => (
                  <tr
                    key={user.id}
                    className={selectedUserID === user.id ? "selected-row" : ""}
                    onClick={() => void onSelectUser(user.id)}
                  >
                    <td>
                      <strong>{user.nickname ?? "未设置昵称"}</strong>
                      <small>{shortID(user.id)}</small>
                    </td>
                    <td>{user.email ?? "无邮箱"}</td>
                    <td><StatusPill tone={user.profile_status === "synced" ? "success" : "warning"}>{user.profile_status === "synced" ? "已同步" : "缺资料"}</StatusPill></td>
                    <td>{formatDate(user.last_sign_in_at)}</td>
                    <td>
                      <button
                        type="button"
                        className="icon-button"
                        aria-label="复制用户 ID"
                        onClick={(event) => {
                          event.stopPropagation();
                          void onCopyUserID(user.id);
                        }}
                      >
                        <Clipboard size={16} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {users.length === 0 && <div className="empty-state">暂无匹配用户</div>}
          </div>

          <UserDetailPanel user={selectedUserDetail} onCopyUserID={onCopyUserID} />
        </div>
      </section>
    </>
  );
}

function UserDetailPanel({ user, onCopyUserID }: { user: AdminUser | null; onCopyUserID: (userID: string) => Promise<void> }) {
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
        <DetailItem label="创建时间" value={formatDate(user.created_at)} />
        <DetailItem label="最后登录" value={formatDate(user.last_sign_in_at)} />
        <DetailItem label="匿名用户" value={user.is_anonymous ? "是" : "否"} />
        <DetailItem label="统计记录" value={`${user.stats_record_count ?? 0} 条`} />
        <DetailItem label="私有表情" value={`${user.private_mood_count ?? 0} 个`} />
      </div>
      <button type="button" className="secondary-button full-width" onClick={() => void onCopyUserID(user.id)}>
        <Clipboard size={17} />
        复制用户 ID
      </button>
    </aside>
  );
}

function UploadRecordsView({
  records,
  allRecords,
  search,
  isLoading,
  onSearchChange,
  onRefresh,
  onCopyUserID
}: {
  records: StatUploadRecord[];
  allRecords: StatUploadRecord[];
  search: string;
  isLoading: boolean;
  onSearchChange: (value: string) => void;
  onRefresh: () => Promise<void>;
  onCopyUserID: (userID: string) => Promise<void>;
}) {
  const userCount = new Set(allRecords.map((record) => record.user_id)).size;
  const namedCount = allRecords.filter((record) => record.nickname).length;

  return (
    <>
      <SectionHeader
        eyebrow="Records"
        title="上传记录"
        description="查看统计上传明细，按昵称或用户 ID 快速定位是谁上传的。"
        action={
          <button type="button" className="secondary-button" onClick={() => void onRefresh()} disabled={isLoading}>
            {isLoading ? <Loader2 className="spin" size={17} /> : <RefreshCw size={17} />}
            刷新
          </button>
        }
      />

      <div className="metric-grid">
        <MetricCard label="最近记录" value={allRecords.length.toString()} />
        <MetricCard label="涉及用户" value={userCount.toString()} />
        <MetricCard label="已匹配昵称" value={namedCount.toString()} />
      </div>

      <section className="panel">
        <div className="panel-title">
          <div>
            <h3>记录明细</h3>
            <p>默认显示最近 500 条上传记录，昵称来自用户资料表。</p>
          </div>
          <label className="search-field">
            <Search size={17} />
            <input
              value={search}
              onChange={(event) => onSearchChange(event.target.value)}
              placeholder="搜索昵称 / 用户 ID / 记录 ID"
            />
          </label>
        </div>

        <div className="table-wrap">
          <table className="data-table records-table">
            <thead>
              <tr>
                <th>用户</th>
                <th>上传时间</th>
                <th>美元金额</th>
                <th>记录 ID</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {records.map((record) => (
                <tr key={record.id}>
                  <td>
                    <strong>{record.nickname ?? "未设置昵称"}</strong>
                    <small>{shortID(record.user_id)}</small>
                  </td>
                  <td>{formatDate(record.timestamp)}</td>
                  <td><strong>{formatUSD(record.usd_amount)}</strong></td>
                  <td><small>{shortID(record.id)}</small></td>
                  <td>
                    <button
                      type="button"
                      className="icon-button"
                      aria-label="复制用户 ID"
                      onClick={() => void onCopyUserID(record.user_id)}
                    >
                      <Clipboard size={16} />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {records.length === 0 && <div className="empty-state">暂无匹配上传记录</div>}
        </div>
      </section>
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
  onCreateMode: () => Promise<void>;
  onSaveMode: () => Promise<void>;
  onDeleteMode: () => Promise<void>;
  onSelectMode: (modeID: string) => void;
  onUpload: (kind: AssetKind, file: File) => Promise<void>;
  onReplace: (assetID: string, file: File) => Promise<void>;
  onSelectAsset: (assetID: string) => Promise<void>;
  onDeleteAsset: (assetID: string) => Promise<void>;
}) {
  const globalModes = modes.filter((mode) => mode.scope === "global").length;
  const userModes = modes.filter((mode) => mode.scope === "user").length;

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
            <button type="button" className="primary-button" onClick={() => void onCreateMode()} disabled={isSaving}>
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
                <h3>{selectedMode ? "模式信息" : "新建模式"}</h3>
                <p>创建全局或指定用户可见的 GIF 表情包。</p>
              </div>
              {selectedMode && (
                <button type="button" className="danger-button" onClick={() => void onDeleteMode()} disabled={isSaving}>
                  <Trash2 size={17} />
                  删除
                </button>
              )}
            </div>

            <div className="form-grid">
              <label>
                <span>模式名称</span>
                <input value={draft.name} maxLength={16} onChange={(event) => onDraftChange({ ...draft, name: event.target.value })} />
              </label>
              <label>
                <span>作用范围</span>
                <select value={draft.scope} onChange={(event) => onDraftChange({ ...draft, scope: event.target.value as MoodScope })}>
                  <option value="global">全局显示</option>
                  <option value="user">指定用户</option>
                </select>
              </label>
              <label>
                <span>玩法</span>
                <select value={draft.behavior} onChange={(event) => onDraftChange({ ...draft, behavior: event.target.value as MoodBehavior })}>
                  <option value="random">随机</option>
                  <option value="manual">手动</option>
                </select>
              </label>
              <label>
                <span>目标用户 ID</span>
                <input
                  value={draft.userId}
                  disabled={draft.scope === "global"}
                  placeholder={draft.scope === "global" ? "全局模式无需填写" : "从用户管理复制 Supabase 用户 ID"}
                  onChange={(event) => onDraftChange({ ...draft, userId: event.target.value })}
                />
              </label>
            </div>

            <div className="action-row">
              <button type="button" className="primary-button" onClick={() => void onSaveMode()} disabled={!selectedMode || isSaving}>
                {isSaving ? <Loader2 className="spin" size={17} /> : <Save size={17} />}
                保存模式
              </button>
            </div>
          </section>

          {selectedMode && (
            <section className="asset-layout">
              <AssetSection title="默认表情" kind="default" mode={selectedMode} selectedAssetID={null} onUpload={onUpload} onReplace={onReplace} onSelect={onSelectAsset} onDelete={onDeleteAsset} />
              <AssetSection title="盈利表情" kind="profit" mode={selectedMode} selectedAssetID={selectedMode.selected_profit_asset_id} onUpload={onUpload} onReplace={onReplace} onSelect={onSelectAsset} onDelete={onDeleteAsset} />
              <AssetSection title="亏损表情" kind="loss" mode={selectedMode} selectedAssetID={selectedMode.selected_loss_asset_id} onUpload={onUpload} onReplace={onReplace} onSelect={onSelectAsset} onDelete={onDeleteAsset} />
            </section>
          )}
        </div>
      </section>
    </>
  );
}

function AssetSection({
  title,
  kind,
  mode,
  selectedAssetID,
  onUpload,
  onReplace,
  onSelect,
  onDelete
}: {
  title: string;
  kind: AssetKind;
  mode: MoodMode;
  selectedAssetID: string | null;
  onUpload: (kind: AssetKind, file: File) => Promise<void>;
  onReplace: (assetID: string, file: File) => Promise<void>;
  onSelect: (assetID: string) => Promise<void>;
  onDelete: (assetID: string) => Promise<void>;
}) {
  const assets = useMemo(
    () => mode.assets.filter((asset) => asset.kind === kind).sort((a, b) => a.sort_order - b.sort_order),
    [mode.assets, kind]
  );
  const canUpload = kind === "default" ? assets.length === 0 : assets.length < 5;

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
            onReplace={onReplace}
            onSelect={onSelect}
            onDelete={onDelete}
          />
        ))}
        {canUpload && <DropUpload kind={kind} onUpload={onUpload} />}
      </div>
    </section>
  );
}

function AssetCard({
  asset,
  selected,
  selectable,
  onReplace,
  onSelect,
  onDelete
}: {
  asset: MoodAsset;
  selected: boolean;
  selectable: boolean;
  onReplace: (assetID: string, file: File) => Promise<void>;
  onSelect: (assetID: string) => Promise<void>;
  onDelete: (assetID: string) => Promise<void>;
}) {
  const [isDragOver, setIsDragOver] = useState(false);

  function handleFile(file: File | undefined) {
    if (!file) return;
    void onReplace(asset.id, file);
  }

  return (
    <article
      className={`asset-card ${selected ? "selected" : ""} ${isDragOver ? "dragging" : ""}`}
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
        <label className="tiny-button">
          <CloudUpload size={15} />
          替换
          <input type="file" accept="image/gif" onChange={(event) => handleFile(event.target.files?.[0])} />
        </label>
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
    <div className={`status ${message.type}`}>
      {message.type === "success" ? <CheckCircle2 size={18} /> : <XCircle size={18} />}
      {message.text}
    </div>
  );
}

function shortID(id: string): string {
  return `${id.slice(0, 8)}...${id.slice(-6)}`;
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

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
