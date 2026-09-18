namespace KrishnaAiGen.Web.Options;

/// <summary>Configuration for locating the KrishnaAiGen repo and catalog behavior.</summary>
public sealed class AgentCatalogOptions
{
    public const string SectionName = "AgentCatalog";

    /// <summary>
    /// Absolute path to the KrishnaAiGen repository root (folder containing <c>.cursor/agents</c>).
    /// When empty, the app walks up from the executable until it finds that folder.
    /// </summary>
    public string? RepoRoot { get; set; }

    /// <summary>Maximum characters of markdown returned by the help bot context builder.</summary>
    public int BotContextCharBudget { get; set; } = 12000;
}
