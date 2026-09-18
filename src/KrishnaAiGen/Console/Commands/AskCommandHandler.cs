using System.ComponentModel.DataAnnotations;
using KrishnaAiGen.Core.Commands;
using KrishnaAiGen.Core.Models;
using KrishnaAiGen.Core.Providers;
using KrishnaAiGen.Core.Repositories;
using KrishnaAiGen.Resources;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace KrishnaAiGen.Console.Commands;

/// <summary>
/// Handles the <c>ask</c> CLI command: sends the user prompt to an AI provider
/// and optionally persists the resulting conversation.
/// </summary>
public sealed class AskCommandHandler : CommandHandler<AskCommandOptions>
{
    private readonly IAiProvider _aiProvider;
    private readonly IConversationRepository _repository;
    private readonly ILogger<AskCommandHandler> _logger;

    /// <summary>Initialises the handler with its required dependencies.</summary>
    public AskCommandHandler(
        IAiProvider aiProvider,
        IConversationRepository repository,
        ILogger<AskCommandHandler> logger)
        : base(logger)
    {
        _aiProvider = aiProvider ?? throw new ArgumentNullException(nameof(aiProvider));
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    /// <summary>
    /// Factory method: creates and configures the <see cref="AskCommandHandler"/>
    /// from the DI container wired inside <paramref name="host"/>.
    /// </summary>
    public static AskCommandHandler SetupCommand(IHost host)
    {
        ArgumentNullException.ThrowIfNull(host);
        return host.Services.GetRequiredService<AskCommandHandler>();
    }

    /// <inheritdoc />
    protected override void Validate(AskCommandOptions options)
    {
        var context = new ValidationContext(options);
        Validator.ValidateObject(options, context, validateAllProperties: true);
    }

    /// <inheritdoc />
    protected override async Task<int> HandleAsync(
        AskCommandOptions options,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(LogMessages.SendingPrompt, options.Prompt.Length);

        var reply = await _aiProvider
            .GetCompletionAsync(options.Prompt, cancellationToken)
            .ConfigureAwait(false);

        System.Console.WriteLine(reply);

        if (options.Save)
        {
            var conversation = new Conversation
            {
                Prompt = options.Prompt,
                Reply = reply
            };

            await _repository
                .AddAsync(conversation, cancellationToken)
                .ConfigureAwait(false);

            _logger.LogInformation(LogMessages.ConversationSaved, conversation.Id);
        }

        return 0;
    }
}
