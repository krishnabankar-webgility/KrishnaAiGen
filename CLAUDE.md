# KrishnaAiGen

Krishna Bankar's personal repo, and the **source of truth for the agent system** across
every AI tool he uses. Also a .NET 8 console app + ASP.NET Core catalog site — see
[AGENTS.md](AGENTS.md) for build commands, remotes, and cloud-agent secrets.

## The agent system lives here, three times over

| Directory | Tool | Status |
|---|---|---|
| [.claude-plugin/](.claude-plugin/) + [plugins/](plugins/) | **Claude Code** | Active. Installed once as a marketplace; applies to every session in every repo. |
| [.cursor/](.cursor/) | Cursor | Licence revoked. Kept as the historical canonical copy — `.cursor/skill-library/*.skill.md` is where the Claude skills were ported from. |
| [.github/](.github/) | GitHub Copilot | Licence revoked. Mirrors of the Cursor agents, plus `.github/prompts/`. |

**When you change agent behavior, change it in [plugins/](plugins/).** The `.cursor/` and
`.github/` trees are no longer executed by anything — treat them as reference. If a skill
is edited in both places, `plugins/` wins.

Full layout and the install steps: [plugins/README.md](plugins/README.md).

## Adding or changing a skill

1. Edit `plugins/krishna-core/skills/<name>/SKILL.md` (or its `reference.md` for the large ones).
2. The `description:` in the frontmatter is what makes Claude pick the skill up — write it
   as trigger phrases you would actually type, not as a summary.
3. `/plugin` then reload, or restart the session, to pick it up.
4. If the change came from a correction in conversation, run `/learn` instead — it does
   this and records why.

## Adding an agent

1. `plugins/krishna-core/agents/<name>.md` with `name`, `description`, `model: inherit`.
2. Keep the body thin: which skills to load, then how to decide. Operational detail belongs
   in a skill, not in the agent prompt — that is what keeps context small.
3. Add a launcher in `plugins/krishna-core/commands/` only if you want a `/slash` for it.
4. Add the row to the routing table in `C:\WG-Agentic\CLAUDE.md` and to the preflight card
   in `plugins/krishna-core/scripts/preflight.ps1`.

## Ephemeral output

One-time reports and scratch files go under `local/ephemeral/` or `logs/` — both gitignored.
The `krishnaaigen-ephemeral-output` skill has the details. Never commit a generated report.

## Git

Default branch for day-to-day work here is **`master`** unless told otherwise (`git-sync`
skill). `origin` is GitHub; `bitbucket` points at `webgility/unify-enterprise`.

Pushing to GitHub matters beyond backup: web and cloud Claude sessions read the agents and
skills straight from the GitHub copy, without a local clone.
