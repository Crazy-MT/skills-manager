# Skills Manager

A native macOS app to manage skills across all your coding agents — Claude Code, Cursor, Codex, Gemini CLI, Qwen Code, Roo Code, Continue, OpenHands, OpenClaw, and more.

[中文文档](README.zh-CN.md)

<img src="SkillsManager_Logo.png" width="80" alt="Skills Manager Icon">

---

## Screenshots

![Discover](docs/screenshots/discover.png)
*Discover skills from skills.sh and inspect them in the native detail view*

![Starred Skills](docs/screenshots/starred.png)
*Manage your library — filter by agent, source, or starred*

---

## What it does

Coding agent skills are scattered everywhere. Each agent has its own format, install path, and management story. Skills Manager brings them together in one place.

- **Discover** skills from [skills.sh](https://skills.sh/) and community repositories, including full-site search beyond the initially loaded list
- **Install** to one or multiple agents at once
- **Test** skills in the built-in LLM sandbox before committing
- **Manage** installed skills — update, remove, star favorites
- **Monitor** all your agents and their skill directories in real time
- **Translate** discovered skill summaries with bundled Chinese descriptions and on-demand LLM fallback for newly loaded entries

## Requirements

- macOS 14 (Sonoma) or later
- One or more coding agents installed (Claude Code, Cursor, Copilot CLI, Codex, Gemini CLI…)

## Installation

Download the latest release from the [Releases](../../releases) page and drag to Applications.

Or build from source:

```bash
git clone https://github.com/yibie/skills-manager.git
cd skills-manager
open SkillsManager.xcodeproj
```

## Supported Agents

Skills Manager detects and scans every agent below through `AgentRegistry`. The `Install target` column marks agents that are available in the current multi-install picker; the remaining agents are still detected and scanned from their registered skills directory when installed locally.

| Agent | Registry ID | Install target |
|-------|-------------|----------------|
| Claude Code | `claude-code` | Yes |
| Amp | `amp` | Scan |
| Cline | `cline` | Scan |
| Codex | `codex` | Yes |
| Cursor | `cursor` | Yes |
| Deep Agents | `deepagents` | Scan |
| Firebender | `firebender` | Scan |
| Gemini CLI | `gemini-cli` | Yes |
| GitHub Copilot | `github-copilot` | Yes |
| Kimi Code CLI | `kimi-cli` | Scan |
| Replit | `replit` | Scan |
| Warp | `warp` | Scan |
| Antigravity | `antigravity` | Scan |
| Augment | `augment` | Yes |
| IBM Bob | `bob` | Scan |
| CodeBuddy | `codebuddy` | Scan |
| Command Code | `command-code` | Yes |
| Continue | `continue` | Yes |
| Cortex Code | `cortex` | Scan |
| Crush | `crush` | Scan |
| Droid | `droid` | Scan |
| Goose | `goose` | Scan |
| iFlow CLI | `iflow-cli` | Yes |
| Junie | `junie` | Scan |
| Kilo Code | `kilo` | Yes |
| Kiro CLI | `kiro-cli` | Yes |
| Kode | `kode` | Scan |
| MCPJam | `mcpjam` | Yes |
| Mistral Vibe | `mistral-vibe` | Scan |
| Mux | `mux` | Yes |
| Neovate | `neovate` | Yes |
| OpenCode | `opencode` | Scan |
| OpenHands | `openhands` | Yes |
| Pi | `pi` | Yes |
| Pochi | `pochi` | Scan |
| Qoder | `qoder` | Scan |
| Qwen Code | `qwen-code` | Yes |
| Roo Code | `roo` | Yes |
| Trae | `trae` | Scan |
| Trae CN | `trae-cn` | Scan |
| Windsurf | `windsurf` | Scan |
| Zencoder | `zencoder` | Scan |
| AdaL | `adal` | Scan |
| OpenClaw | `openclaw` | Scan |

## Skill Management Philosophy: Project-Local via Symlinks

Skills Manager embraces a powerful skill management philosophy inspired by [Jim Liu](https://github.com/JimLiu)'s deep thinking on coding agent ergonomics. The core insight is simple but profound: **put skills where they're used, not where they'll clutter**.

### The problem with global skills

When you install skills globally, every skill becomes visible to every project. At first glance this seems convenient — install once, use everywhere. But there's a hidden cost. Every coding agent operates within a finite context window — think of it as a workbench with limited surface area. While skills typically only load their names and descriptions (not full content) into context by default, dozens of globally installed skills still add up. Those summaries alone consume meaningful space in the context window. And whenever the agent decides a skill is relevant to the current task, it loads the full content — the more global skills you have, the higher the chance of false-positive triggers, further wasting precious context space that should be reserved for your actual code and conversation.

Project-local installation solves this elegantly. Only skills genuinely relevant to the current project sit on the workbench. The agent works with exactly what it needs and nothing more. Context space stays lean, reasoning stays focused, results stay better.

### Symlinks: one source, many projects

Jim Liu's second insight is about the *how* of project-local installation. Rather than copying skill files into each project — which creates divergence, makes updates painful, and prevents contributing fixes back upstream — use symbolic links (symlinks).

If you're used to Windows, think of symlinks as the Unix equivalent of shortcuts. There's one real file on disk, with lightweight pointers in as many places as you need. Change the real file, and every pointer sees the change immediately.

The workflow works in three deliberate steps:

**Step 1: Clone skill repositories to a central directory.** Keep the originals in one place, like `~/GitHub/baoyu-skills/skills/`. This is where `git pull` happens, this is where fixes get committed, this is the single source of truth.

**Step 2: Create symlinks from your project to the originals.** Inside your project, Skills Manager creates `.agents/skills/<skill-name>/` as a symlink pointing back to the original in `~/GitHub/`. The skill lives in the project directory structure but the bytes live on disk only once.

**Step 3: Create an entry point for your agent.** A final symlink `.claude/skills` → `.agents/skills` gives Claude Code (or any compatible agent) the path it needs to discover project-local skills. This chain — `.claude/skills` → `.agents/skills/` → `~/GitHub/baoyu-skills/skills/<skill>/` — is transparent, portable, and zero-copy.

### Why symlinks beat copying

The benefits compound over time:

- **One update, all projects current.** `git pull` in the source repo and every project using that skill instantly sees the latest version. No hunting through multiple project directories, no stale copies lurking in forgotten corners.

- **Fix a bug, contribute back upstream.** You're using a skill in your writing project and notice it mishandles a particular Markdown edge case. Fix it right there — because the symlink points to the original, your edit goes straight into `~/GitHub/baoyu-skills/skills/`. Commit, push, open a PR. You've just improved the skill for the entire open-source community without leaving your workflow.

- **No duplication, no drift.** A skill stored in ten projects as ten separate copies will diverge into ten subtly different versions within weeks. Symlinks guarantee there's always exactly one version — the current one from source.

### You don't need to remember commands

This might sound like it requires memorizing terminal commands for `ln -s`, remembering exact paths, and carefully managing symlink hygiene. It doesn't. Skills Manager handles everything through its native macOS UI:

- **Configure source directories** in Settings — point to wherever your skill repos live
- **Open a project** and click **"Link Skill"** — browse available skills from your sources
- **One click links it** — symlinks and entry points are created automatically
- **Manage visually** — see which skills are linked, unlink with a click, check entry point status at a glance

Tell the app what you want in plain language ("link the baoyu-comic skill to this project") and it does the rest. The philosophy is intentional; the implementation is invisible.

### A note of appreciation

This project-local symlink approach was first articulated and refined by [Jim Liu](https://github.com/JimLiu), whose thoughtful analysis of coding agent ergonomics and context-window economics has shaped how many developers think about skill management. His core argument — that skills belong in projects, not globally, and that symlinks are the correct mechanism — has become foundational to Skills Manager's architecture. We're grateful for his clarity of thought and generous sharing of ideas that make tools like this possible.

## Usage: Managing Project Skills via Symlinks

This section is a step-by-step walkthrough of the entire symlink-based skill management workflow. If the philosophy section above convinced you, here's how to put it into practice.

### Step 1: Prepare your skill source directories

You need one or more directories that contain skill files. Skills Manager supports two layouts:

**Layout A: Standalone skill directory.** The directory directly contains `SKILL.md`:

```
~/GitHub/knowledge-skill/
├── SKILL.md
└── references/
```

**Layout B: Skill repository.** A top-level directory containing multiple skill subdirectories, each with its own `SKILL.md`:

```
~/GitHub/baoyu-skills/skills/
├── baoyu-comic/
│   └── SKILL.md
├── baoyu-design/
│   └── SKILL.md
└── baoyu-writing/
    └── SKILL.md
```

Both layouts are automatically detected by Skills Manager. You don't need to create any specific structure — just keep your cloned skill repos as they are.

### Step 2: Register source directories in Settings

Open Skills Manager, press `⌘,` to open the Settings window.

1. Scroll to the **"Skill Source Directories"** section at the bottom
2. Click **"Add Directory"** and use the file picker to locate your skill source directory (e.g. `~/GitHub/baoyu-skills/skills/`)
3. You can add multiple source directories — each one will be scanned independently

At this point, Skills Manager doesn't do anything yet — it simply remembers these paths for later use when you're working inside a project.

> **Tip:** If the file picker opens at an unexpected location, press `⌘⇧G` to type a path manually (e.g. `~/GitHub/baoyu-skills/skills`).

### Step 3: Open your project

Back in the main window, click the **"Open Project"** button (folder icon) in the toolbar and select your project's root directory.

Once opened, a **"Project"** entry appears in the sidebar, and the main content area switches to the project skills view. You'll see:

- Any existing `SKILL.md` or `.cursor/rules/*.mdc` files listed under **"Project Skills"**
- An entry point status indicator at the top
- An empty state message if no skills are present yet

### Step 4: Link a skill

At the bottom of the project view, click the **"Link Skill"** button. A sheet opens listing every available skill across all configured source directories, showing each skill's name, description, and source path.

- Use the search field to filter quickly
- Already-linked skills show a green ✓ badge and cannot be re-linked
- Click **"Link"** next to any skill to connect it to your project

Behind the scenes, linking performs two operations:

1. Creates a symlink at `<project>/.agents/skills/<skill-name>/` → pointing to the skill's source directory
2. Auto-creates `<project>/.claude/skills` → `.agents/skills` entry-point symlink if it doesn't already exist

The sheet closes automatically and the newly linked skill appears in the **"Linked Skills"** list immediately.

### Step 5: Verify entry point status

At the top of the project view, an entry point indicator shows the current state:

- **Green checkmark + "Entry point active"** — `.claude/skills → .agents/skills` is properly set up. Claude Code can discover all linked skills. Use the "Remove" button to tear down this symlink if you no longer want agent access to project skills.
- **Yellow warning + "Entry point not set up"** — the entry point is missing. Normally, Skills Manager auto-creates it when you link your first skill. If it doesn't for some reason, click **"Create"** to manually establish it.

### Step 6: Day-to-day usage

**Verify Claude Code sees your skills:** Run Claude Code in the project directory, and linked skills will appear in its skill list. You can also check manually in the terminal:

```bash
ls -la .claude/skills    # Should show a symlink pointing to .agents/skills
ls -la .agents/skills/   # Should list all linked skill directories
```

**Unlink a skill:** In the "Linked Skills" list, click the "Unlink" button next to any skill. This removes only the symlink in `.agents/skills/<name>/` — the original files in your source directory are never touched.

**Update skills:** Because every project links to the same source directory, a single `git pull` updates every project at once:

```bash
cd ~/GitHub/baoyu-skills
git pull
```

All projects using any skill from this repo instantly see the latest version. No individual project updates needed.

**Fix a bug and contribute back upstream:** Notice an issue with a skill while using it in a project? Fix it directly — your edit goes straight into the source directory. Then:

```bash
cd ~/GitHub/baoyu-skills
git add . && git commit -m "fix: resolve edge case in Markdown handling"
git push
```

Open a PR on GitHub. You've improved the skill for the entire open-source community without ever leaving your normal workflow.

### Directory structure after setup

After completing the steps above, your project directory looks like this:

```
your-project/
├── .claude/
│   └── skills → ../.agents/skills          # Entry-point symlink
├── .agents/
│   └── skills/
│       ├── knowledge-skill → ~/GitHub/knowledge-skill   # Symlink to source
│       └── baoyu-comic → ~/GitHub/baoyu-skills/skills/baoyu-comic
├── .cursor/
│   └── rules/
│       └── my-rule.mdc                     # Project-embedded skill (if any)
└── src/
    └── ...
```

Every skill file lives exactly once — in the source directory. Projects contain only lightweight symlink pointers. `.claude/skills` serves as the entry point, letting Claude Code walk the chain to discover all linked skills and read their original `SKILL.md` files.

### Symlinks vs. global installation: a comparison

| Aspect | Symlinks (project-level) | Global installation |
|--------|-------------------------|---------------------|
| Context footprint | Only project-relevant skills loaded | All skill summaries consume context space |
| False-positive triggers | Low — only relevant skills get loaded | High — any global skill may be triggered |
| Updates | `git pull` once, all projects current | Manual per-install or per-agent update |
| Bug fixes | Edit source directly, open a PR | Diff unclear, hard to contribute back |
| Cross-project consistency | Always points to the same canonical source | May have divergent copies, version skew |

## Discover and Translation

Discover starts fast from a local cache at `~/.skills-manager/cache/discover-directory.json`, then refreshes from skills.sh in the background. Search uses the skills.sh full-site API when online and falls back to cached query snapshots when offline.

The app bundles a generated description translation catalog for Chinese summaries and still keeps an on-demand translation button as a temporary fallback for newly loaded or uncached descriptions. Local Ollama and LM Studio endpoints are normalized to IPv4 loopback (`127.0.0.1`) at runtime to avoid macOS `localhost` resolving to IPv6 `::1`.

## Architecture

Pure local architecture — no backend, works offline except for network-backed features like Discover refresh/search, detail loading, translation fallback, and sandbox LLM calls. Reads and writes agent config files directly and uses local Git history for version management.

Built with SwiftUI + Swift 6, SwiftData, macOS 14+.

## Terminal UI

The repository also includes a terminal UI in `tui/`.

Current status:
- **Blessed TUI:** complete for the current scope and treated as the primary terminal implementation
- **Ink TUI:** historical backup/reference only, no longer the target runtime

Official CLI command:

```bash
cd tui
npm exec skills-manager
```

For a global command, run once inside `tui/`:

```bash
npm link
```

Then launch from anywhere with:

```bash
skills-manager
```

The Blessed TUI currently supports:
- three-panel keyboard-first navigation
- discover via [skills.sh](https://skills.sh/)
- install / uninstall / star
- source-file opening and discover source-page opening
- search, detail overlays, full refresh
- version history is temporarily disabled
- local / plugin differentiation, including Codex plugin cache and Pi package resources

## Roadmap

- [ ] Auto-update detection for discovered skills
- [ ] Skill conflict detection across agents
- [ ] Export / import skill sets
- [ ] Team sync via shared skills repository

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT — see [LICENSE](LICENSE).
