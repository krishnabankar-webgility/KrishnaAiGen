# How to install — step by step

Written for: you, following this once, from scratch.

This answers three things: **where** those `/plugin …` lines get typed, **what** they do,
and **what "restart" means** for each of the four ways you use Claude.

---

## First: what kind of command is this?

`/plugin marketplace add …` is **not** a PowerShell or `cmd` command. Do not paste it into a
terminal — it will just say "command not found".

It is a **slash command**, typed into the **Claude chat input box itself** — the same box
where you type "fix this bug". Claude Code reads anything starting with `/` as an
instruction to itself rather than as a message.

So: open a Claude chat, click in the message box, type the line, press Enter.

---

## Step 0 — finish the rename first (one time only)

The plugin is installed **by path**, so install it at its final name or you will have to
redo it.

1. Close **VS Code**, **Cursor**, and any terminal window sitting inside `C:\WG-Agentic\AskAI`.
2. Open a plain PowerShell window (Start menu → type `powershell` → Enter).
3. Paste this and press Enter:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "C:\WG-Agentic\AskAI\.claude\scripts\finish-rename.ps1"
   ```

4. It should print `Rename complete.` If it says `STILL LOCKED`, something still has the
   folder open — close it and run the same line again. The script is safe to re-run.

After this, the folder is `C:\WG-Agentic\KrishnaAiGen`.

> Everything *inside* the repo is already renamed — solution, projects, namespaces, docs.
> The build and all 36 tests pass. Only the folder name was left.

---

## Step 1 — open Claude in the workspace

Open **VS Code** on the folder `C:\WG-Agentic` (File → Open Folder), then open the Claude
chat panel. Any of your four surfaces works, but do the install once from here.

---

## Step 2 — add the marketplace

In the Claude chat box, type this and press Enter:

```
/plugin marketplace add C:\WG-Agentic\KrishnaAiGen
```

**What this does:** tells Claude Code "there is a catalogue of plugins at this folder".
It reads `KrishnaAiGen\.claude-plugin\marketplace.json` and registers a marketplace named
`krishnaaigen`. It installs nothing yet.

You should see it confirm the marketplace was added, listing 2 available plugins.

---

## Step 3 — install the two plugins

Type each line, pressing Enter after each:

```
/plugin install krishna-core@krishnaaigen
```

```
/plugin install wd-core@krishnaaigen
```

**What `name@marketplace` means:** `krishna-core` is the plugin; `krishnaaigen` is the
marketplace it comes from. Same shape as `npm install package@registry`.

- **krishna-core** — your personal workflow: Jira, Git, Bitbucket, Slack, Confluence,
  SQL Server, Kibana, Jenkins, the daily digest, Windows/VPN fixes, plus the session
  preflight that runs automatically.
- **wd-core** — Webgility Desktop: the 16 `wd-*` domain agents and the
  lead / dev / qa / review / scout roles.

You may be asked to confirm. Say yes.

---

## Step 4 — restart

"Restart" here means **start a fresh Claude session**, not reboot Windows. Plugins,
hooks and MCP servers are loaded when a session starts, so an already-open chat will not
see them.

| Where you use Claude | How to restart it |
|---|---|
| **VS Code extension** | Close the Claude chat panel and open a new chat (the `+` / "New chat" button). If it still looks stale, run **Ctrl+Shift+P → Developer: Reload Window**. |
| **Claude Code desktop app** | Start a **new conversation**. If MCP servers look wrong, quit the app completely (check the system tray) and reopen it. |
| **Terminal (`claude` in cmd/PowerShell)** | Press **Ctrl+C** twice to exit, then run `claude` again. |
| **Browser (claude.ai)** | Nothing to do — the browser cannot use local plugins at all. See the last section. |

---

## Step 5 — check it worked

In the **new** session, you should see a **workspace readiness card** appear before you
type anything: a table of your 8 repo checkouts with their branches, which credentials are
missing, and the routing table. That card is the proof the install took — it is produced by
the `SessionStart` hook inside `krishna-core`.

Then verify by typing these in the chat box:

| Type this | Expect to see |
|---|---|
| `/plugin` | `krishna-core` and `wd-core`, both installed |
| `/agents` | 14 personal agents + 21 `wd-*` agents |
| `/mcp` | 11 local servers, plus your claude.ai connectors |
| just `/` | the list should offer `/jira`, `/git`, `/bitbucket`, `/customization`, `/ship-to-qa`, `/kibana`, `/confluence`, `/slack`, `/db`, `/daily-update`, `/sys-fix`, `/learn`, `/route` |

Then try a real one:

```
/jira what is UD-33334 about
```

---

## If something does not work

**The `/plugin` command is not recognised.**
You are typing it in a terminal, not in the Claude chat box. Or the Claude Code version is
old — run `claude update` in a terminal, then try again.

**"marketplace not found" or the path is rejected.**
The folder must exist with that exact name. Check `C:\WG-Agentic\KrishnaAiGen\.claude-plugin\marketplace.json`
is there. If the folder is still called `AskAI`, Step 0 has not been done.

**No readiness card at the top of a new session.**
The hook did not run. It needs `powershell` on PATH. Test it by hand:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\WG-Agentic\KrishnaAiGen\plugins\krishna-core\scripts\preflight.ps1"
```

If that prints the table, the script is fine and the problem is the hook registration —
reinstall `krishna-core`.

**An MCP server shows as failed in `/mcp`.**
Almost always a missing credential or a missing runtime. The readiness card names which
environment variables are absent. `bitbucket`, `jenkins` and the database servers need
`C:\WG-Agentic\wg-ai-workspace\.env`; the `dotnet`-based ones (`wo-db`, `jenkins`,
`mssql-*`) need the .NET SDK on PATH.

**You want to change something later.**
Edit the files under `KrishnaAiGen\plugins\`, then start a new session. No reinstall needed —
the plugin is read from that folder, not copied elsewhere.

---

## Updating later

The plugins live in this git repo, so:

```powershell
cd C:\WG-Agentic\KrishnaAiGen
git pull
```

and start a new session. Only if you **add a new plugin** to `marketplace.json` do you also
need `/plugin marketplace update krishnaaigen`.

---

## The browser (claude.ai) — why it is different

Local plugins are files on this machine, so a browser session cannot load them. That is the
reason this all lives in a GitHub repo rather than in `C:\Users\krishna.bankar\.claude`.

For a web session, point it at the repo on GitHub and ask it to read the skill you want, e.g.
`plugins/krishna-core/skills/jira-workflow/reference.md`. It then follows the same instructions
without a local install. Push your changes first — the web only sees what is on GitHub.
