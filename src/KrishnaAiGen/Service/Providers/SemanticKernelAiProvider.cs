using KrishnaAiGen.App.Configuration;
using KrishnaAiGen.Core.Providers;
using KrishnaAiGen.Resources;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace KrishnaAiGen.Service.Providers;

/// <summary>
/// Semantic Kernel–based implementation of <see cref="IAiProvider"/>.
/// Replace the stub body with a real <c>Microsoft.SemanticKernel</c> invocation once
/// an API key is configured.
/// </summary>
public sealed class SemanticKernelAiProvider : IAiProvider
{
    private readonly AiOptions _options;
    private readonly ILogger<SemanticKernelAiProvider> _logger;

    /// <summary>Initialises the provider with configuration and a logger.</summary>
    public SemanticKernelAiProvider(
        IOptions<AiOptions> options,
        ILogger<SemanticKernelAiProvider> logger)
    {
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    /// <inheritdoc />
    public async Task<string> GetCompletionAsync(
        string prompt,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(prompt);

        _logger.LogDebug(LogMessages.InvokingAiModel, _options.ModelId);

        // TODO: replace with real Semantic Kernel / OpenAI call.
        await Task.Delay(0, cancellationToken).ConfigureAwait(false);

        return $"[{_options.ModelId}] Echo: {prompt}";
    }
}
