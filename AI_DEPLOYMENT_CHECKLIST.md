# AI 股票分析部署清单

## Railway 服务

仓库：`zy364601065/daily_stock_analysis`

构建配置：

```toml
[build]
builder = "DOCKERFILE"
dockerfilePath = "docker/Dockerfile"

[deploy]
startCommand = "python main.py --serve-only --host 0.0.0.0 --port $PORT"
healthcheckPath = "/api/health"
healthcheckTimeout = 120
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10
```

非敏感环境变量：

```text
WEBUI_HOST=0.0.0.0
MAX_WORKERS=1
ENV_FILE=/app/data/runtime.env
DATABASE_PATH=/app/data/stock_analysis.db
LLM_CHANNELS=anspire
LLM_ANSPIRE_ENABLED=true
LLM_ANSPIRE_PROTOCOL=openai
LLM_ANSPIRE_BASE_URL=https://open-gateway.anspire.cn/v6
LLM_ANSPIRE_MODELS=Doubao-Seed-2.0-lite
```

最后由管理员填写的 Secret：

```text
LLM_ANSPIRE_API_KEY=<模型 API Key>
INTERNAL_API_TOKEN=<随机长 Token>
```

持久化卷挂载：`/app/data`。

## Supabase Edge Function

函数：`stock-analysis`，必须开启 JWT 验证。

最后填写：

```text
AI_SERVICE_URL=<Railway HTTPS 地址>
AI_SERVICE_TOKEN=db4f88f8cbf26e47302fed3fd96beae37a53fe4287cfab8c5817d943c2929ad1
```

缺少 URL 或 Token 时，函数返回 503，不会尝试调用外部 AI 服务。
