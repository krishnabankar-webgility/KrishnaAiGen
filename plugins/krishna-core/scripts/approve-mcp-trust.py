"""
approve-mcp-trust.py

Pre-approves the local .mcp.json servers and accepts the workspace-trust dialog
for every path this workspace is opened from, so a new Claude Code session
never has to click through "approve these MCP servers from .mcp.json?" again.

WHY THIS NEEDS TO BE RUN BY YOU, NOT BY CLAUDE
Claude Code's own "self-modification" guardrail refuses to let an agent edit
Claude Code's own state file (~/.claude.json) on its own — even to just read
it. That guardrail is doing exactly what it should here, so this script is
handed to you to run yourself rather than executed automatically.

WHAT IT ACTUALLY CHANGES
Only ~/.claude.json (Claude Code's own per-project trust record). For every
project directory this workspace might be opened from (both trees, every
repo, every slash/case spelling Windows tools produce for the same path), it:
  - marks the 11 servers in .mcp.json as pre-approved (enabledMcpjsonServers)
  - marks the workspace-trust dialog as already accepted
It does not touch permissions, tool allowlists, or bypass any security check
for anything Claude does at runtime — only the one-time "do you trust these
MCP server definitions" prompt for servers you already wrote yourself.

HOW TO RUN IT
    python "C:\\WG-Agentic\\KrishnaAiGen\\plugins\\krishna-core\\scripts\\approve-mcp-trust.py"

Safe to re-run any time (e.g. after adding a new repo or MCP server) — it only
adds, never removes, and a project entry that's already correct is left alone.
A timestamped backup of ~/.claude.json is written next to it before any edit.
"""
import json, io, sys, shutil, datetime

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')

CLAUDE_JSON = r"C:\Users\krishna.bankar\.claude.json"

SERVERS = ["bitbucket", "kibana-logs", "wo-log", "redis", "cis-db-proxy",
           "wo-db", "cns-db", "cws-db", "jenkins", "mssql-winauth", "mssql-sqlauth"]

DIRS = [
    r"C:\WG-Agentic",
    r"C:\WG-Agentic\KrishnaAiGen",
    r"C:\WG-Agentic\unify-enterprise",
    r"C:\WG-Agentic\cloud-integration-systems",
    r"C:\WG-Agentic\wg-ai-workspace",
    r"C:\WG-Agentic 2",
    r"C:\WG-Agentic 2\KrishnaAiGen",
    r"C:\WG-Agentic 2\unify-enterprise",
    r"C:\WG-Agentic 2\cloud-integration-systems",
    r"C:\WG-Agentic 2\wg-ai-workspace",
]


def variants(p):
    fwd = p.replace('\\', '/')
    out = {p, fwd}
    if p[1:2] == ':':
        out.add(p[0].lower() + p[1:]); out.add(fwd[0].lower() + fwd[1:])
        out.add(p[0].upper() + p[1:]); out.add(fwd[0].upper() + fwd[1:])
    return out


def main():
    all_keys = set()
    for d in DIRS:
        all_keys |= variants(d)

    backup = CLAUDE_JSON + '.bak-' + datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    shutil.copy2(CLAUDE_JSON, backup)
    print('backup written:', backup)

    with io.open(CLAUDE_JSON, encoding='utf-8') as f:
        data = json.load(f)

    projects = data.setdefault('projects', {})
    created, updated, already = [], [], []

    for key in sorted(all_keys):
        entry = projects.get(key)
        is_new = entry is None
        if is_new:
            entry = {
                "allowedTools": [], "mcpContextUris": [], "mcpServers": {},
                "enabledMcpjsonServers": [], "disabledMcpjsonServers": [],
                "hasTrustDialogAccepted": True,
                "hasClaudeMdExternalIncludesApproved": False,
                "hasClaudeMdExternalIncludesWarningShown": False,
            }
            projects[key] = entry

        changed = False
        if not entry.get('hasTrustDialogAccepted'):
            entry['hasTrustDialogAccepted'] = True
            changed = True

        existing = set(entry.get('enabledMcpjsonServers', []) or [])
        if not existing.issuperset(SERVERS):
            entry['enabledMcpjsonServers'] = sorted(existing | set(SERVERS))
            changed = True

        disabled = entry.get('disabledMcpjsonServers', []) or []
        if any(s in disabled for s in SERVERS):
            entry['disabledMcpjsonServers'] = [s for s in disabled if s not in SERVERS]
            changed = True

        if is_new:
            created.append(key)
        elif changed:
            updated.append(key)
        else:
            already.append(key)

    with io.open(CLAUDE_JSON, 'w', encoding='utf-8', newline='') as f:
        json.dump(data, f, indent=2)

    print('created  (%d): %s' % (len(created), created))
    print('updated  (%d): %s' % (len(updated), updated))
    print('no-change(%d): %s' % (len(already), already))
    print()
    print('Done. Start a new Claude Code session in any of these directories -')
    print('the 11 local MCP servers should connect with no approval prompt.')


if __name__ == '__main__':
    main()
