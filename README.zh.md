# feishu-cc-toolkit

在飞书里用本机 Claude Code，**哪怕 Anthropic 只能走代理才连得上**。这是
[zarazhangrui 的 `lark-channel-bridge`][upstream]（飞书 ↔ Claude Code 桥）之上的伴生工具层，
**不是 fork**——它把上游从 npm 装好、工作在它之上，补齐让它在「国内网络 + 代理」环境下跑通的那几块，
并做成一把安装。

> English: [README.md](README.md)。桥的核心是 zarazhangrui 的 MIT 作品，见 [CREDITS.md](CREDITS.md)。

## 在 zara 的桥基础上解决了哪些问题

[zara 的 `lark-channel-bridge`][upstream] 本身是个好桥，但它默认的环境不是人人都满足。
本工具包在**不 fork** 它的前提下把这些缺口补上：

| 光用上游桥的问题 | 本工具包补的 |
|---|---|
| **在外网代理后面连不上。** claude 访问 Anthropic 必须走代理，但飞书 SDK 一探到 `http(s)_proxy` 就给**所有**飞书请求套代理——飞书是国内服务，被外网代理劫持就 `CONNECT` 被 reset / bot 身份解析失败；而 claude **不走**代理又撞 `403`。 | **代理隔离（proxy-split）**：桥本体不带代理（飞书直连），代理只注入给 `claude` 子进程。→ [docs/proxy-split.md](docs/proxy-split.md) |
| **飞书里看不到上下文用量。** 飞书入口没有进度条，不知道会话满没满。 | **`/ctx`** —— 报当前会话的 `已用 / 窗口` token 占用。 |
| **安装繁琐、还容易再弄坏。** 手搭代理 wrapper、launchd plist、钉死 node 版本的守护进程，以及一个会悄悄把代理重新弄坏的 `start`。 | **一把安装**：`install-deps.sh` 从 npm 拉上游，`install.sh` 用安全姿势配好 wrapper + plist + 守护进程，还自动绕过首启撞锁。 |
| **运维坑没人写下来。** 建群、免 @ 投递、工作目录绑定、403/`CONNECT` 排错。 | 一份 [docs/](docs/) **运维手册**——[建群与免@](docs/group-setup.md)、[工作目录](docs/workspaces.md)、[排错](docs/troubleshooting.md)。 |

## 适合谁

你在飞书里通过 `lark-channel-bridge` 用 Claude Code，且**访问 Anthropic 必须走外网 HTTP 代理**，
而飞书（国内服务）必须**直连**。光用上游的桥在这种环境会挂，本工具包干净地修好它。
如果你根本不需要代理，那你可能只想要 `/ctx` 命令和这份文档。

## 安装

> 干净机器（什么都没装）或在代理后面？按 [docs/install-from-scratch.md](docs/install-from-scratch.md)
> 走完整链路。下面是快捷版：

```bash
# 0. 拉本工具包
git clone https://github.com/xueyongcheng/feishu-cc-toolkit && cd feishu-cc-toolkit

# 1. 从 npm 装上游依赖（zara 的桥 + lark-cli），不用自己 clone 任何仓
bash scripts/install-deps.sh

# 2. 绑飞书 bot（交互式扫码，没法自动化）
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY \
  lark-channel-bridge run --profile claude --agent claude

# 3. 配置 + 安装本工具包
cp .env.example .env    # 填 PROXY_HTTP
bash scripts/install.sh
```

> 上游的桥**不是**塞进本仓、也不用你 clone——它是 npm 包 `lark-channel-bridge`，
> `install-deps.sh`（或 `npm i -g lark-channel-bridge`）替你拉下来。出处与署名见
> [CREDITS.md](CREDITS.md)。干净机器完整流程见
> [docs/install-from-scratch.md](docs/install-from-scratch.md)。

安装器会：把代理隔离 wrapper 写进 `~/.lark-channel/bin`，装好 `ctx.sh` 和 `/ctx` 命令，
生成一份 launchd plist（wrapper 目录排在 `PATH` 最前、代理只隔离给 claude 子进程），
并加载守护进程。配置有变随时重跑。`scripts/uninstall.sh` 可回退（你的桥配置不动）。

## 验证

```bash
lark-channel-bridge status                 # 在运行，且有 PID
# wrapper 的 PROXY_HTTP 来自 plist、不是当前 shell。裸跑会报 "PROXY_HTTP not set"
# （正常现象，不是装坏），要测就内联设一下：
PROXY_HTTP=http://127.0.0.1:7897 ~/.lark-channel/bin/claude -p test   # 能回，不是 403
```

守护进程日志应有 `ws/connected` + `chats-fetched`，且**没有** `channel: proxy detected`。
若装完 `status` 显示有任务但**没 PID**，跑一次 `lark-channel-bridge restart`（首启撞锁的一次性现象，
详见 [docs/troubleshooting.md](docs/troubleshooting.md)）。

## 为什么需要它（一句话）

飞书 SDK 一旦探到 `http(s)_proxy` 就把**所有**飞书请求强行套上代理（它不读 `no_proxy`、
也不读 `all_proxy`），而飞书是国内服务、被外网代理劫持就 CONNECT 被 reset；可 `claude`
访问 Anthropic 又**必须**走代理（直连撞 403）。两者共用同一个 `http(s)_proxy` 变量名，
唯一干净的隔离办法是**进程级 wrapper**。详见 [docs/proxy-split.md](docs/proxy-split.md)。

## 平台

守护进程依赖 macOS（launchd）。wrapper 和 `ctx.sh` 是纯 POSIX `sh` / `python3`，可移植；
只有安装/守护那条链路是 macOS 特定的。

## 许可

MIT，见 [LICENSE](LICENSE)。上游桥：MIT，[zarazhangrui][upstream]。

[upstream]: https://github.com/zarazhangrui/feishu-claude-code-bridge
