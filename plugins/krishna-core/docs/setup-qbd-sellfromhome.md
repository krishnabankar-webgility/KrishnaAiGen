# QuickBooksDesktop MCP — direct connection (honest answer first, then the build)

## Generic server, specific file — one setting decides which

Server name is **`QuickBooksDesktop`**, not `qbd-sellfromhome` — same reasoning as the Shopify
server being `shopify` and not `shopify-mewebg` (see `setup-shopify.md`): the company file is a
fact about *this machine's* setup, not the server's identity. Nothing in the server code or its
`wg-mcp.json` entry names `SellFromHome.qbw` — it reads the path from **`QBD_COMPANY_FILE`** in
`wg-ai-workspace/.env` (already set there, alongside `QBD_APP_NAME`). Pointing this at a different
company file — a different sandbox, a teammate's own test file — is a one-line `.env` change,
nothing else to touch. The doc title/filename still says "SellFromHome" because that's *this*
setup's target file, same way `setup-cis-qa-postgres.md` is titled after QA even though the server
it builds (`cis-db`) is generic too.

## Is it possible? Yes, with two real limits — read this before building it

This uses the exact same automation layer `unify-enterprise` itself uses to talk to QuickBooks
Desktop (confirmed by reading `wg.eCC.AccountingSoftwareFactory\QuickBooksCommon.vb`): a COM
session (`QBSessionManager`/`RequestProcessor`), `OpenConnection2(appID, appName, connectionType)`,
then `BeginSession(companyFileName, mode)`. A standalone MCP server can do the same thing against
`SellFromHome.qbw`. Two things are **not** solvable by code, only by you, once:

1. **The one-time "Allow this application to access this company file" dialog.** QuickBooks
   Desktop shows this the first time any new application name connects — no SDK flag skips it,
   because it's QuickBooks' own security prompt, not something the calling app controls. You click
   it once, in the QuickBooks UI, same as you would for any new integration.
   - On that dialog, check **"Yes, always; allow access even if QuickBooks is not running"** and
     **"Allow this application to login automatically"**. That's what gets you the "closed QBD"
     case in your ask: after this one click, the MCP server's connection attempt will make
     QuickBooks **launch itself** (QuickBooks.exe starts, because the COM session has to run
     inside it — there's no way to drive the file with QuickBooks fully absent from memory) and
     open the session without prompting again or needing you to click through the UI.
   - Without that checkbox, every connection when QB is closed re-shows a dialog that only you
     can click — which would defeat "without login explicitly."

2. **Working file-open mode.** QuickBooks Desktop allows **multiple automated connections to the
   same already-open company file** — that's the normal case today: WD already holds a session
   open against `SellFromHome.qbw` while you also have it open and visible, and it works, because
   they're both pointed at the *same* file. `QuickBooksCommon.vb`'s own retry/force-close logic
   only triggers when a session is left open for a **different** file than the one being
   requested — same-file concurrent access is the supported path, not the edge case. So: the MCP
   server working "with or without you having it open" is expected to hold, same as it already
   does for WD itself. What it can't do is bypass QuickBooks' own single-user file lock if you
   deliberately open `SellFromHome.qbw` in **single-user mode** on a different machine or a
   second QuickBooks install pointed at the same file over a network path — that's a QuickBooks
   limitation, not one this server introduces. On one machine, one QuickBooks install, you're fine.

Net: fully possible, genuinely headless after one checkbox, safe to run alongside your own manual
use of the same file. Not possible: a connection with literally zero QuickBooks process ever
running, or clicking through the one-time dialog for you — that one has to be you, same reason
Claude Code can't register a new credentialed MCP server for itself (see
`claude-code-new-mcp-server-blocked` in memory) — a security prompt that exists specifically so an
unattended process can't silently grant itself company-file access.

## Why QBXMLRP2 instead of the QBFC interop WD uses

WD's own code is built against a specific year's `Interop.QBFC##.dll` (version-pinned to the SDK
installed when that project was built). For a small standalone server, that pinning is a
liability — it breaks the moment QuickBooks is upgraded. The design below uses the **QBXMLRP2**
COM object instead (`QBXMLRP2.RequestProcessor2`, late-bound, no interop DLL reference needed):
same underlying SDK, same session/file-lock semantics as QBFC, but it takes and returns **raw
QBXML strings** rather than strongly-typed objects — which also matches this repo's existing
"generic `execute_sql`, no table allow-list" shape (`cis-qa-pg`, `cis-db-proxy`). The tradeoff:
Claude has to construct QBXML requests itself (it already knows the schema — QuickBooks ships
`qbxmlops##.xsd`/the `OSR` tool, and `qbsdklog.txt` shows live examples of exactly what WD sends)
rather than calling a typed `get_customer(id)`-style tool. If that proves painful in practice,
the next step is a typed wrapper layer on top of the same connection — not a reason to block on it
now.

## Already in place

`wg-ai-workspace/.env` now has:
```
QBD_COMPANY_FILE=C:\Users\Public\Documents\Intuit\QuickBooks\Company Files\SellFromHome.qbw
QBD_APP_NAME=KrishnaAiGen-QBD-MCP
```
— the single point of change for which company file this server talks to. Windows user env var
**`QBD_CREDS`** (`un:<username>, pwd:<password>`) already holds the company file's login — see
`wd-local-diagnostics` skill §4. QuickBooks Desktop itself must already be installed and licensed
on this machine (it is — that's how WD runs today).

## Step 1 — create the server files yourself

Same reason as every other server here (`setup-shopify.md`, `setup-cis-qa-postgres.md`): a new
auto-running credentialed background process is blocked by Claude Code's safety classifier
(`[Unauthorized Persistence]`) — this has to be your hand, not mine.

Create `C:\WG-Agentic\wg-ai-workspace\.mcp-servers\quickbooks-desktop\` with:

**`quickbooks-desktop.csproj`:**
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0-windows</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="ModelContextProtocol" Version="0.2.0-preview.1" />
    <PackageReference Include="Microsoft.Extensions.Hosting" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Logging.Console" Version="8.0.0" />
  </ItemGroup>
</Project>
```

**`Program.cs`:**
```csharp
using System.Runtime.InteropServices;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Console;
using ModelContextProtocol.Server;
using System.ComponentModel;

var builder = Host.CreateApplicationBuilder(args);
builder.Logging.AddConsole(o => o.LogToStandardErrorThreshold = LogLevel.Trace);
builder.Services.AddMcpServer().WithStdioServerTransport().WithToolsFromAssembly();
await builder.Build().RunAsync();

[McpServerToolType]
public static class QbdTools
{
    // Both read from wg-ai-workspace/.env (loaded via --env-file in wg-mcp.json) — the server
    // itself has no file/app name hardcoded. This is the single point of change for which
    // company file this talks to; nothing else in this project names SellFromHome.
    static readonly string CompanyFile = Environment.GetEnvironmentVariable("QBD_COMPANY_FILE")
        ?? throw new InvalidOperationException("QBD_COMPANY_FILE is missing — set it in wg-ai-workspace/.env");
    static readonly string AppName = Environment.GetEnvironmentVariable("QBD_APP_NAME") ?? "KrishnaAiGen-QBD-MCP";

    [McpServerTool, Description(
        "Run a raw QBXML request against the configured QuickBooks Desktop company file (set via " +
        "QBD_COMPANY_FILE in wg-ai-workspace/.env) via QBXMLRP2 automation. Pass a full qbXML " +
        "document (same schema WD itself sends — see qbsdklog.txt at " +
        "C:\\ProgramData\\Intuit\\QuickBooks\\qbsdklog.txt for live examples, or the QuickBooks " +
        "SDK's OSR tool for the schema). Read AND write requests both go through this one tool " +
        "(CustomerQueryRq, InvoiceAddRq, etc.) — only safe to write against a file you know is a " +
        "local sandbox, not a customer's data; check wd-local-diagnostics before writing.")]
    public static string ExecuteQbxml(string qbXmlRequest)
    {
        dynamic? rp = null;
        string ticket = "";
        try
        {
            var rpType = Type.GetTypeFromProgID("QBXMLRP2.RequestProcessor")
                ?? throw new InvalidOperationException("QBXMLRP2 COM object not found — is QuickBooks Desktop (with SDK support) installed?");
            rp = Activator.CreateInstance(rpType)!;
            rp.OpenConnection2("", AppName, 1 /* localQBD */);
            ticket = rp.BeginSession(CompanyFile, 2 /* omDontCare — attach to an already-open session on this file if there is one */);
            string response = rp.ProcessRequest(ticket, qbXmlRequest);
            return response;
        }
        catch (COMException ex)
        {
            return $"QuickBooks COM error 0x{ex.HResult:X8}: {ex.Message}";
        }
        finally
        {
            try { if (rp != null && ticket != "") rp.EndSession(ticket); } catch { }
            try { rp?.CloseConnection(); } catch { }
        }
    }
}
```

> `omDontCare` (mode `2`) is what lets this attach to a file you already have open manually
> instead of fighting over the lock — matching the "shouldn't block manual UI use" requirement.

## Step 2 — register it, then clear the one-time QuickBooks dialog

Add to `C:\WG-Agentic\KrishnaAiGen\.claude\mcp\wg-mcp.json` (note `--env-file`, same as the Node
servers — this is what gets `QBD_COMPANY_FILE`/`QBD_APP_NAME` into the process):
```json
"quickbooks-desktop": {
  "command": "dotnet",
  "args": [
    "run",
    "--project",
    "C:/WG-Agentic/wg-ai-workspace/.mcp-servers/quickbooks-desktop/quickbooks-desktop.csproj"
  ],
  "env": {
    "QBD_COMPANY_FILE": "C:\\Users\\Public\\Documents\\Intuit\\QuickBooks\\Company Files\\SellFromHome.qbw",
    "QBD_APP_NAME": "KrishnaAiGen-QBD-MCP"
  }
}
```
`dotnet run` doesn't support `--env-file` the way the Node servers' `node --env-file` does, so
these two values are passed as `env` directly in the `wg-mcp.json` entry instead — **this is now
the one place they live for this process**, not `.env` (keep `.env`'s copy too, for any other
tooling that reads it, but this `env` block is what the server itself actually sees).

> **Must use backslashes, not forward slashes, in `QBD_COMPANY_FILE`** — unlike every other path
> in this repo's MCP config. QuickBooks' own `QBInstanceFinder` matches this value against the
> exact (backslash) path it tracks internally for an already-open file; a forward-slash path fails
> that match and produces a confusing `0x80040408: Could not start QuickBooks` error even when
> QuickBooks is open on the right file. Confirmed the hard way 2026-10-15 — see
> `qbd-sellfromhome-mcp-feasibility` in memory. If you ever see that error with QB already open,
> check `C:\ProgramData\Intuit\QuickBooks\qbsdklog.txt` for the real `QBInstanceFinder`/HRESULT
> line before assuming it's the one-time approval dialog.

Then:
```
powershell -ExecutionPolicy Bypass -File C:\WG-Agentic\KrishnaAiGen\.claude\scripts\sync-workspace.ps1
```

**Before the first real use**, trigger one connection yourself (run the project directly, or ask
Claude to call `execute_qbxml` with a trivial `<CompanyQueryRq/>`) while QuickBooks is open on
the configured company file. QuickBooks will show the one-time "Allow access" dialog — pick
**Yes, always** and check **both** boxes mentioned above. After that, it's done permanently for
this app name; a new session afterward (QB open or closed) connects silently.

## Changing behavior later

| To change | Edit |
|---|---|
| **Which company file this talks to** | The `QBD_COMPANY_FILE` value in the `wg-mcp.json` entry's `env` block above (and `.env`'s copy, for consistency) — the single point of change; no code edit, no rename. Only a file you've confirmed is safe to read/write should go here (`SellFromHome.qbw` is — see `wd-local-diagnostics` §4 before pointing this at anything else) |
| Add a typed tool instead of raw QBXML (e.g. `list_invoices`) | Add another `[McpServerTool]` method in `Program.cs` that builds the QBXML internally and calls the same connection logic |
| Credentials | `QBD_CREDS` Windows user env var — not actually read by this server today since QBXMLRP2 authenticates via the already-approved application + Windows session, not a login prompt; kept for reference/consistency with `wd-local-diagnostics` |
| Handing this to a teammate | Same server file, same `wg-mcp.json` entry name (`quickbooks-desktop`) — only their own `env` block differs (their own company file path/app name) |

## Troubleshooting: "server shows up but won't connect"

If Claude Code lists `quickbooks-desktop` but logs `CONNECTION_CLOSED`, it's almost always a
**build failure**, not QuickBooks itself (QBD being open/closed doesn't matter at this stage — the
process never gets far enough to try a COM connection). Check by running the build directly:
```
cd C:\WG-Agentic\wg-ai-workspace\.mcp-servers\quickbooks-desktop
dotnet build
```
If that fails, `dotnet run` fails identically every time Claude Code tries to spawn it, which is
indistinguishable from a closed connection in the MCP log. Fix the build error, confirm
`dotnet build` succeeds, then start a new Claude Code session (or reload the window) to respawn it.

