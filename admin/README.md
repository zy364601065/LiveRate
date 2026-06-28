# 众安助手管理

本地后台用于管理众安助手运营数据。当前包含两个模块：

- 用户管理：查看 Supabase Auth 用户、昵称资料、统计记录数量和私有表情数量。
- 表情管理：维护统计面板 GIF 表情包。App 只读取 Supabase 中可见的表情模式，不再在 App 内新增或上传 GIF。

## 启动

```bash
cd admin
cp .env.example .env.local
```

在 `.env.local` 填入：

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `ADMIN_PASSWORD`

然后运行：

```bash
npm install
npm run dev
```

打开 `http://127.0.0.1:5173`，输入 `ADMIN_PASSWORD` 登录。

## 权限说明

`SUPABASE_SERVICE_ROLE_KEY` 只在本地 Node 服务端使用，不会进入浏览器。不要把 `.env.local` 提交到 Git。
