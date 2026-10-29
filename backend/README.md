# 诗心问墨后端

后端使用 Python 3.10+ 标准库，无额外包依赖。Qt 客户端只连接此服务；模型密钥、上游地址和模型名仅由后端环境变量管理。接口为 `POST /api/chat`（SSE 流）和 `GET /health`。

## 本机启动（Windows PowerShell）

在项目根目录运行以下命令，按提示输入密钥。脚本会将后端作为隐藏的本机进程启动，检查健康状态并显示进程 PID；密钥仅进入后端进程环境。由于 Windows PowerShell 可能限制本地脚本，下面只对这一次启动放宽执行策略。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\backend\Start-Local.ps1
```

修改后端代码后，使用同一命令加 `-Restart` 重新启动并输入密钥。脚本只会关闭本机端口 8765 上通过健康检查确认的 Python 后端。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\backend\Start-Local.ps1 -Restart
```

在自己的终端中输入服务端密钥，再启动服务。下面的输入提示不会回显密钥，也不会把密钥写进命令历史。请勿将真实密钥写进项目文件、日志或截图。

```powershell
$aiSecret = Read-Host '输入 AI 服务端密钥' -AsSecureString
$env:AI_UPSTREAM_API_KEY = [System.Net.NetworkCredential]::new('', $aiSecret).Password
Remove-Variable aiSecret
try { python backend/server.py } finally { Remove-Item Env:\AI_UPSTREAM_API_KEY }
```

默认绑定 `127.0.0.1:8765`，客户端默认连接该地址。本机只允许本机访问；未设置密钥时 `/health` 仍可访问，但聊天返回友好的 503 错误。密钥应在后端进程环境或服务器私有配置中注入。参考 [`backend/.env.example`](.env.example) 查看其余设置项。服务不会自动读取 `.env` 文件。

默认关闭模型思考模式，并将单次回复上限设为 4096 tokens。若模型仍因长度上限中断，客户端会保留已生成内容并提供「继续生成」。后端会检查上游结束原因，不会把长度截断误报为完整回复。可通过 `AI_MAX_OUTPUT_TOKENS` 调整上限（最高 8192）；更换其他 OpenAI 兼容服务且不支持 `thinking` 字段时，可设置 `AI_UPSTREAM_THINKING=omit`。

## 部署

正式部署时，在 HTTPS 反向代理后运行后端，并设置 `AI_LISTEN_HOST`、`AI_CLIENT_TOKENS`、`AI_UPSTREAM_API_KEY`。服务在非本机地址监听时若缺少访问令牌会拒绝启动。建议给不同用户或安装分配不同令牌；服务按令牌限制每分钟请求、每日请求总量及并发。访问令牌属于**客户端身份凭据**，不是模型 API Key。不要把共享令牌硬编码进可分发的客户端；可由受控部署流程给客户端进程设置 `YIJUANSHANHE_AI_ACCESS_TOKEN`。公开互联网服务还应在反向代理处加入用户身份验证与监控。

构建客户端时设置服务器地址（不包含模型路径、密钥或模型名）：

```powershell
cmake -S . -B build/release -DCMAKE_PREFIX_PATH=D:/QT/6.5.3/mingw_64 -DYIJUANSHANHE_AI_SERVICE_URL=https://your-domain.example
cmake --build build/release
```

开发时也可用进程环境变量 `YIJUANSHANHE_AI_SERVICE_URL` 覆盖构建地址。普通用户界面没有这些配置项。远程服务未部署前，客户端只会尝试本机地址；本地典藏等功能仍可独立使用。不要在公网直接暴露无 TLS 的后端端口。

上游接口兼容 OpenAI Chat Completions。当前示例采用 DeepSeek 官方文档的 `https://api.deepseek.com/chat/completions` 和 `deepseek-flash`；模型、地址均可在后端更换。后端只向客户端流式返回最终回答，不转发模型密钥、思考链或上游详细错误。参考 [DeepSeek 官方调用文档](https://api-docs.deepseek.com/api/responses) 与 [Chat Completions 接口](https://api-docs.deepseek.com/api/create-chat-completion/)。

## 测试

```powershell
python -m unittest discover -s backend -p 'test_*.py' -v
ctest --test-dir build/journey-verify --output-on-failure
```

后端测试使用模拟上游，不消耗模型额度，也不需要密钥。
