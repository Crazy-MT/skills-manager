# Skills Manager

一个原生 macOS 应用，用于管理所有编程助手的技能（Skills）——支持 Claude Code、Cursor、Codex、Gemini CLI、Qwen Code、Roo Code、Continue、OpenHands、OpenClaw 等。

<img src="SkillsManager_Logo.png" width="80" alt="Skills Manager 图标">

---

## 截图

![发现](docs/screenshots/discover.png)
*从 skills.sh 发现技能，并在原生详情视图中查看*

![已收藏技能](docs/screenshots/starred.png)
*管理你的技能库——按助手、来源或收藏筛选*

---

## 功能

编程助手的技能分散在各处。每个助手有自己的格式、安装路径和管理方式。Skills Manager 将它们统一管理。

- **发现**技能，来自 [skills.sh](https://skills.sh/) 和社区仓库，支持全站搜索（超出初始加载列表）
- **安装**到一个或多个助手
- **测试**技能，在内置 LLM 沙箱中预先验证
- **管理**已安装的技能——更新、移除、收藏
- **监控**所有助手及其技能目录，实时更新
- **翻译**发现的技能摘要，内置中文描述，对新增条目支持按需 LLM 翻译

## 系统要求

- macOS 14（Sonoma）或更高版本
- 至少安装一个编程助手（Claude Code、Cursor、Copilot CLI、Codex、Gemini CLI 等）

## 安装

从 [Releases](../../releases) 页面下载最新版本，拖入 Applications 文件夹。

或从源码构建：

```bash
git clone https://github.com/yibie/skills-manager.git
cd skills-manager
open SkillsManager.xcodeproj
```

## 支持的助手

Skills Manager 通过 `AgentRegistry` 检测并扫描以下所有助手。标记为"安装目标"的助手可在多安装选择器中使用；其余助手在本地安装后仍会被检测并扫描其技能目录。

| 助手 | 注册 ID | 安装目标 |
|-------|-------------|----------------|
| Claude Code | `claude-code` | 是 |
| Amp | `amp` | 仅扫描 |
| Cline | `cline` | 仅扫描 |
| Codex | `codex` | 是 |
| Cursor | `cursor` | 是 |
| Deep Agents | `deepagents` | 仅扫描 |
| Firebender | `firebender` | 仅扫描 |
| Gemini CLI | `gemini-cli` | 是 |
| GitHub Copilot | `github-copilot` | 是 |
| Kimi Code CLI | `kimi-cli` | 仅扫描 |
| Replit | `replit` | 仅扫描 |
| Warp | `warp` | 仅扫描 |
| Antigravity | `antigravity` | 仅扫描 |
| Augment | `augment` | 是 |
| IBM Bob | `bob` | 仅扫描 |
| CodeBuddy | `codebuddy` | 仅扫描 |
| Command Code | `command-code` | 是 |
| Continue | `continue` | 是 |
| Cortex Code | `cortex` | 仅扫描 |
| Crush | `crush` | 仅扫描 |
| Droid | `droid` | 仅扫描 |
| Goose | `goose` | 仅扫描 |
| iFlow CLI | `iflow-cli` | 是 |
| Junie | `junie` | 仅扫描 |
| Kilo Code | `kilo` | 是 |
| Kiro CLI | `kiro-cli` | 是 |
| Kode | `kode` | 仅扫描 |
| MCPJam | `mcpjam` | 是 |
| Mistral Vibe | `mistral-vibe` | 仅扫描 |
| Mux | `mux` | 是 |
| Neovate | `neovate` | 是 |
| OpenCode | `opencode` | 仅扫描 |
| OpenHands | `openhands` | 是 |
| Pi | `pi` | 是 |
| Pochi | `pochi` | 仅扫描 |
| Qoder | `qoder` | 仅扫描 |
| Qwen Code | `qwen-code` | 是 |
| Roo Code | `roo` | 是 |
| Trae | `trae` | 仅扫描 |
| Trae CN | `trae-cn` | 仅扫描 |
| Windsurf | `windsurf` | 仅扫描 |
| Zencoder | `zencoder` | 仅扫描 |
| AdaL | `adal` | 仅扫描 |
| OpenClaw | `openclaw` | 仅扫描 |

## 技能管理理念：基于符号链接的项目本地化管理

Skills Manager 秉承一种强大的技能管理理念，灵感来源于 [Jim Liu](https://github.com/JimLiu) 对编程助手人机工程学的深入思考。核心理念简单而深刻：**把技能放在使用它们的地方，而不是让它们堆积在全局空间**。

### 全局安装的问题

当你全局安装技能时，每个技能对所有项目都可见。乍看之下这很方便——一次安装，处处使用。但这里有隐藏的成本。每个编程助手都在有限的上下文窗口内运行——可以把它想象成一个表面积有限的工作台。虽然技能通常默认只加载名称和描述（而非完整内容）到上下文中，但数十个全局安装的技能仍然会累积。光是这些摘要就消耗了上下文窗口中可观的空间。而且每当助手判定某个技能与当前任务相关时，它会加载完整内容——全局技能越多，误触发的概率就越高，进一步浪费了本应留给实际代码和对话的宝贵上下文空间。

项目本地安装优雅地解决了这个问题。只有与当前项目真正相关的技能才会出现在工作台上。助手只使用它确实需要的东西，不多不少。上下文空间保持精简，推理保持专注，结果保持更好。

### 符号链接：一份源文件，多个项目

Jim Liu 的第二个洞见是关于项目本地安装的*实现方式*。与其将技能文件复制到每个项目中——这会导致版本分化、更新困难、无法向上游贡献修复——不如使用符号链接（symlink）。

如果你习惯使用 Windows，可以把符号链接理解为 Unix 版的快捷方式。磁盘上只有一份真实文件，在需要的地方放置轻量级的指针。修改真实文件，所有指针立即看到变化。

工作流程分为三个步骤：

**第一步：将技能仓库克隆到中心目录。** 把源文件放在一个地方，比如 `~/GitHub/baoyu-skills/skills/`。这里执行 `git pull`，这里提交修复，这里是唯一的真相来源。

**第二步：从项目创建指向源文件的符号链接。** 在项目内部，Skills Manager 创建 `.agents/skills/<skill-name>/` 作为指向 `~/GitHub/` 中源文件的符号链接。技能在项目目录结构中可见，但文件在磁盘上只存储一次。

**第三步：为助手创建入口点。** 最终的符号链接 `.claude/skills` → `.agents/skills` 为 Claude Code（或任何兼容的助手）提供了发现项目本地技能所需的路径。这条链路——`.claude/skills` → `.agents/skills/` → `~/GitHub/baoyu-skills/skills/<skill>/`——是透明的、可移植的、零拷贝的。

### 为什么符号链接优于复制

好处随时间累积：

- **一次更新，所有项目同步。** 在源仓库中 `git pull`，每个使用该技能的项目立即看到最新版本。无需在多个项目目录中寻找，不存在遗忘角落里过时的副本。

- **修复 bug，向上游贡献。** 你在写作项目中使用某个技能，发现它对某个 Markdown 边界情况处理不当。直接修复——因为符号链接指向源文件，你的编辑直接进入 `~/GitHub/baoyu-skills/skills/`。提交、推送、发起 PR。你刚刚为整个开源社区改进了这个技能，无需离开日常工作流程。

- **无重复，无分化。** 一个技能以十份独立副本存储在十个项目中，几周内就会分化成十个微妙不同的版本。符号链接保证始终只有一个版本——来自源文件的最新版本。

### 你不需要记住命令

这听起来可能需要记住 `ln -s` 等终端命令，需要记住精确路径，需要小心管理符号链接的规范性。实际上不需要。Skills Manager 通过原生 macOS 界面处理一切：

- **在设置中配置源目录**——指向你的技能仓库所在位置
- **打开项目**，点击**"关联技能"**——浏览源目录中的可用技能
- **一键关联**——符号链接和入口点自动创建
- **可视化管理**——查看已关联的技能、一键取消关联、随时查看入口点状态

用自然语言告诉应用你想要什么（"将 baoyu-comic 技能关联到这个项目"），其余由应用完成。理念是有意为之的；实现是无感的。

### 致谢

这种项目本地符号链接方案最早由 [Jim Liu](https://github.com/JimLiu) 提出并完善。他对编程助手人机工程学和上下文窗口经济性的深入分析，影响了许多开发者对技能管理的思考方式。他的核心论点——技能属于项目而非全局空间，符号链接是正确的实现机制——已成为 Skills Manager 架构的基础。我们感谢他清晰的思考以及慷慨分享的见解，这些使像这样的工具成为可能。

## 使用指南：通过符号链接管理项目技能

本节是完整符号链接技能管理工作流程的逐步操作指南。如果上面的理念部分说服了你，以下是具体的实践方法。

### 第一步：准备技能源目录

你需要一个或多个包含技能文件的目录。Skills Manager 支持两种布局：

**布局 A：独立技能目录。** 目录直接包含 `SKILL.md`：

```
~/GitHub/knowledge-skill/
├── SKILL.md
└── references/
```

**布局 B：技能仓库。** 顶级目录包含多个技能子目录，每个子目录有自己的 `SKILL.md`：

```
~/GitHub/baoyu-skills/skills/
├── baoyu-comic/
│   └── SKILL.md
├── baoyu-design/
│   └── SKILL.md
└── baoyu-writing/
    └── SKILL.md
```

两种布局都会被 Skills Manager 自动检测。你不需要创建任何特定结构——保持克隆的技能仓库原样即可。

### 第二步：在设置中注册源目录

打开 Skills Manager，按 `⌘,` 打开设置窗口。

1. 滚动到底部的**"技能源目录"**区域
2. 点击**"添加目录"**，使用文件选择器找到你的技能源目录（例如 `~/GitHub/baoyu-skills/skills/`）
3. 你可以添加多个源目录——每个都会被独立扫描

此时 Skills Manager 还没有做任何操作——它只是记住了这些路径，供以后在项目中工作时使用。

> **提示：** 如果文件选择器打开的位置不符合预期，按 `⌘⇧G` 手动输入路径（例如 `~/GitHub/baoyu-skills/skills`）。

### 第三步：打开你的项目

回到主窗口，点击工具栏中的**"打开项目"**按钮（文件夹图标），选择你的项目根目录。

打开后，侧边栏会出现**"项目"**条目，主内容区域切换到项目技能视图。你会看到：

- **"项目技能"**下列出任何已有的 `SKILL.md` 或 `.cursor/rules/*.mdc` 文件
- 顶部显示入口点状态指示器
- 如果还没有技能，显示空状态提示

### 第四步：关联技能

在项目视图底部，点击**"关联技能"**按钮。会弹出一个面板，列出所有配置的源目录中的可用技能，显示每个技能的名称、描述和源路径。

- 使用搜索框快速筛选
- 已关联的技能显示绿色 ✓ 标记，不可重复关联
- 点击任意技能旁的**"关联"**按钮将其连接到项目

后台操作包括：

1. 创建符号链接 `<project>/.agents/skills/<skill-name>/` → 指向技能源目录
2. 自动创建 `<project>/.claude/skills` → `.agents/skills` 入口点符号链接（如果尚不存在）

面板自动关闭，新关联的技能立即出现在**"已关联技能"**列表中。

### 第五步：验证入口点状态

项目视图顶部有一个入口点指示器，显示当前状态：

- **绿色勾号 + "入口点已激活"**——`.claude/skills → .agents/skills` 已正确设置。Claude Code 可以发现所有关联的技能。点击"移除"按钮可拆除此符号链接，不再让助手访问项目技能。
- **黄色警告 + "入口点未设置"**——入口点缺失。通常，Skills Manager 在关联第一个技能时会自动创建。如果因某种原因未创建，点击**"创建"**手动建立。

### 第六步：日常使用

**验证 Claude Code 能看到你的技能：** 在项目目录中运行 Claude Code，关联的技能会出现在其技能列表中。你也可以在终端中手动检查：

```bash
ls -la .claude/skills    # 应显示指向 .agents/skills 的符号链接
ls -la .agents/skills/   # 应列出所有关联的技能目录
```

**取消关联技能：** 在"已关联技能"列表中，点击技能旁的"取消关联"按钮。这只移除 `.agents/skills/<name>/` 中的符号链接——源目录中的原始文件不会被触碰。

**更新技能：** 因为每个项目都链接到同一个源目录，一次 `git pull` 即可更新所有项目：

```bash
cd ~/GitHub/baoyu-skills
git pull
```

所有使用此仓库中任何技能的项目立即看到最新版本，无需逐个更新项目。

**修复 bug 并向上游贡献：** 在项目中使用技能时发现问题？直接修复——你的编辑直接进入源目录。然后：

```bash
cd ~/GitHub/baoyu-skills
git add . && git commit -m "fix: 修复 Markdown 处理的边界情况"
git push
```

在 GitHub 上发起 PR。你刚刚为整个开源社区改进了这个技能，无需离开日常工作流程。

### 设置完成后的目录结构

完成上述步骤后，你的项目目录结构如下：

```
your-project/
├── .claude/
│   └── skills → ../.agents/skills          # 入口点符号链接
├── .agents/
│   └── skills/
│       ├── knowledge-skill → ~/GitHub/knowledge-skill   # 指向源文件的符号链接
│       └── baoyu-comic → ~/GitHub/baoyu-skills/skills/baoyu-comic
├── .cursor/
│   └── rules/
│       └── my-rule.mdc                     # 项目内嵌技能（如有）
└── src/
    └── ...
```

每个技能文件只在源目录中存在一份。项目只包含轻量级的符号链接指针。`.claude/skills` 作为入口点，让 Claude Code 遍历链路发现所有关联的技能并读取其原始 `SKILL.md` 文件。

### 符号链接 vs 全局安装：对比

| 方面 | 符号链接（项目级） | 全局安装 |
|--------|-------------------------|---------------------|
| 上下文占用 | 仅加载项目相关技能 | 所有技能摘要消耗上下文空间 |
| 误触发概率 | 低——仅相关技能被加载 | 高——任何全局技能都可能被触发 |
| 更新 | 一次 `git pull`，所有项目同步 | 每个安装或每个助手手动更新 |
| Bug 修复 | 直接编辑源文件，发起 PR | 差异不清晰，难以向上游贡献 |
| 跨项目一致性 | 始终指向同一规范源 | 可能存在分化的副本，版本偏移 |

## 发现与翻译

发现功能从本地缓存 `~/.skills-manager/cache/discover-directory.json` 快速启动，然后在后台从 skills.sh 刷新。在线时搜索使用 skills.sh 全站 API，离线时回退到缓存的查询快照。

应用内置描述翻译目录，提供中文摘要，同时保留按需翻译按钮作为新加载或未缓存描述的临时回退方案。本地 Ollama 和 LM Studio 端点会在运行时规范化为 IPv4 回环地址（`127.0.0.1`），以避免 macOS 将 `localhost` 解析为 IPv6 `::1`。

## 架构

纯本地架构——无后端服务，除发现刷新/搜索、详情加载、翻译回退和沙箱 LLM 调用等网络功能外均可离线工作。直接读写助手配置文件，使用本地 Git 历史进行版本管理。

使用 SwiftUI + Swift 6、SwiftData 构建，要求 macOS 14+。

## 终端 UI

仓库的 `tui/` 目录中还有一个终端 UI。

当前状态：
- **Blessed TUI：** 当前功能范围已完成，作为主要的终端实现
- **Ink TUI：** 仅作为历史备份/参考，不再是目标运行时

官方 CLI 命令：

```bash
cd tui
npm exec skills-manager
```

如需全局命令，在 `tui/` 目录中运行一次：

```bash
npm link
```

然后从任意位置启动：

```bash
skills-manager
```

Blessed TUI 当前支持：
- 三面板键盘优先导航
- 通过 [skills.sh](https://skills.sh/) 发现技能
- 安装 / 卸载 / 收藏
- 打开源文件，打开发现源页面
- 搜索、详情浮层、完整刷新
- 版本历史暂时禁用
- 本地 / 插件区分，包括 Codex 插件缓存和 Pi 包资源

## 路线图

- [ ] 已发现技能的自动更新检测
- [ ] 跨助手的技能冲突检测
- [ ] 导出 / 导入技能集
- [ ] 通过共享技能仓库实现团队同步

## 贡献

欢迎提交 Issue 和 PR。请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 了解指南。

## 许可证

MIT — 详见 [LICENSE](LICENSE)。