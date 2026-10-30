using BusinessLogic.DTOs.Responses;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Constants;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class QuotaService : IQuotaService
{
    private readonly IQuotaRepository _quotaRepository;
    private readonly IUserRepository _userRepository;
    private readonly QuotaSettings _settings;
    private readonly ILogger<QuotaService> _logger;

    public QuotaService(
        IQuotaRepository quotaRepository,
        IUserRepository userRepository,
        QuotaSettings settings,
        ILogger<QuotaService> logger)
    {
        _quotaRepository = quotaRepository;
        _userRepository = userRepository;
        _settings = settings;
        _logger = logger;
    }

    public async Task<QuotaSnapshotDto> GetSnapshotAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await _userRepository.GetByIdAsync(userId, cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy người dùng.");
        var held = await _quotaRepository.GetHeldTokensAsync(userId, null, DateTime.UtcNow, cancellationToken);

        return new QuotaSnapshotDto(user.TokenQuota, user.TokenBalance, held, Math.Max(0, user.TokenBalance - held));
    }

    public Task<int> ReserveAsync(
        Guid userId,
        Guid messageId,
        int requestedTokens,
        TimeSpan lease,
        CancellationToken cancellationToken = default)
    {
        if (requestedTokens <= 0)
        {
            throw new BadRequestException("Số token cần giữ chỗ phải lớn hơn 0.");
        }

        return _quotaRepository.ExecuteWithUserLockAsync(userId, async user =>
        {
            if (user is null)
            {
                throw new UnauthorizedException("Người dùng không tồn tại.");
            }

            var turn = await _quotaRepository.GetTurnAsync(messageId, cancellationToken);
            if (turn is null || turn.SenderRole != SenderRole.Assistant
                || turn.TurnState != ChatTurnStates.Processing || turn.QuotaSettledAt is not null)
            {
                throw new ConflictException("Lượt chat không ở trạng thái chờ giữ chỗ quota.");
            }

            var now = DateTime.UtcNow;
            var held = await _quotaRepository.GetHeldTokensAsync(userId, messageId, now, cancellationToken);
            var available = user.TokenBalance - held;
            if (available <= 0)
            {
                throw new QuotaExceededException("Bạn đã hết quota khả dụng hoặc có yêu cầu đang chờ quyết toán.");
            }

            turn.ReservedTokens = (int)Math.Min(available, requestedTokens);
            turn.LeaseExpiresAt = now.Add(lease);
            return turn.ReservedTokens;
        }, cancellationToken);
    }

    public async Task<bool> ReleaseAsync(Guid messageId, Guid? leaseId, CancellationToken cancellationToken = default)
    {
        var ownerId = await _quotaRepository.GetTurnOwnerIdAsync(messageId, cancellationToken);
        if (ownerId is null)
        {
            return false;
        }

        return await _quotaRepository.ExecuteWithUserLockAsync(ownerId.Value, async _ =>
        {
            var turn = await _quotaRepository.GetTurnAsync(messageId, cancellationToken);
            if (turn is null || turn.TurnState != ChatTurnStates.Processing || turn.QuotaSettledAt is not null
                || (leaseId is not null && turn.LeaseId != leaseId))
            {
                return false;
            }

            turn.TurnState = ChatTurnStates.Failed;
            turn.ReservedTokens = 0;
            turn.LeaseExpiresAt = null;
            return true;
        }, cancellationToken);
    }

    public async Task<QuotaSettlementResultDto> SettleAsync(
        Guid messageId,
        Guid eventId,
        CancellationToken cancellationToken = default)
    {
        var ownerId = await _quotaRepository.GetTurnOwnerIdAsync(messageId, cancellationToken);
        if (ownerId is null)
        {
            _logger.LogWarning("Quota settle skipped: turn {MessageId} not found (event {EventId})", messageId, eventId);
            return new QuotaSettlementResultDto(QuotaSettlementStatus.NotFound, 0, 0);
        }

        var result = await _quotaRepository.ExecuteWithUserLockAsync(ownerId.Value, async user =>
        {
            var turn = await _quotaRepository.GetTurnAsync(messageId, cancellationToken);
            if (user is null || turn is null)
            {
                return new QuotaSettlementResultDto(QuotaSettlementStatus.NotFound, 0, 0);
            }

            // The lock on the user row makes check-then-set atomic: a replayed event sees QuotaSettledAt.
            if (turn.QuotaSettledAt is not null)
            {
                return new QuotaSettlementResultDto(QuotaSettlementStatus.AlreadySettled, 0, user.TokenBalance);
            }

            if (turn.TurnState != ChatTurnStates.Completed)
            {
                return new QuotaSettlementResultDto(QuotaSettlementStatus.NotCompleted, 0, user.TokenBalance);
            }

            // Charge the usage stored with the result, not the amount carried by the event payload.
            var charged = Charge(user, turn.TokensUsed, messageId);
            turn.ReservedTokens = 0;
            turn.QuotaSettledAt = DateTime.UtcNow;
            return new QuotaSettlementResultDto(QuotaSettlementStatus.Settled, charged, user.TokenBalance);
        }, cancellationToken);

        _logger.LogInformation(
            "Quota settle {Status} for turn {MessageId} (event {EventId}): charged {Charged}",
            result.Status, messageId, eventId, result.TokensCharged);
        return result;
    }

    public async Task<QuotaRecoveryResultDto> RecoverAsync(CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var released = 0;
        var charged = 0;
        var settled = 0;

        var expiredIds = await _quotaRepository.GetExpiredReservationIdsAsync(
            now.AddSeconds(-_settings.LeaseGraceSeconds), _settings.RecoveryBatchSize, cancellationToken);
        foreach (var messageId in expiredIds)
        {
            switch (await ExpireReservationAsync(messageId, cancellationToken))
            {
                case ExpireOutcome.Released:
                    released++;
                    break;
                case ExpireOutcome.Charged:
                    charged++;
                    break;
            }
        }

        var unsettledIds = await _quotaRepository.GetUnsettledCompletedTurnIdsAsync(
            now.AddMinutes(-_settings.SettleCompletedAfterMinutes), _settings.RecoveryBatchSize, cancellationToken);
        foreach (var messageId in unsettledIds)
        {
            var result = await SettleAsync(messageId, Guid.Empty, cancellationToken);
            if (result.Status == QuotaSettlementStatus.Settled)
            {
                settled++;
            }
        }

        if (released + charged + settled > 0)
        {
            _logger.LogWarning(
                "Quota recovery: released {Released}, charged {Charged} expired reservations; settled {Settled} completed turns",
                released, charged, settled);
        }

        return new QuotaRecoveryResultDto(released, charged, settled);
    }

    private async Task<ExpireOutcome> ExpireReservationAsync(Guid messageId, CancellationToken cancellationToken)
    {
        var ownerId = await _quotaRepository.GetTurnOwnerIdAsync(messageId, cancellationToken);
        if (ownerId is null)
        {
            return ExpireOutcome.Skipped;
        }

        return await _quotaRepository.ExecuteWithUserLockAsync(ownerId.Value, async user =>
        {
            var turn = await _quotaRepository.GetTurnAsync(messageId, cancellationToken);
            var cutoff = DateTime.UtcNow.AddSeconds(-_settings.LeaseGraceSeconds);
            // Re-check under the lock: the turn may have completed or been retried since the scan.
            if (user is null || turn is null || turn.TurnState != ChatTurnStates.Processing
                || turn.QuotaSettledAt is not null || turn.LeaseExpiresAt is null || turn.LeaseExpiresAt >= cutoff)
            {
                return ExpireOutcome.Skipped;
            }

            var outcome = ExpireOutcome.Released;
            if (_settings.ChargeReservationWhenUsageUnknown && turn.ReservedTokens > 0)
            {
                Charge(user, turn.ReservedTokens, messageId);
                turn.QuotaSettledAt = DateTime.UtcNow;
                outcome = ExpireOutcome.Charged;
            }

            turn.TurnState = ChatTurnStates.Failed;
            turn.ResultStatus = ChatResultStatuses.UsageUnknown;
            turn.ReservedTokens = 0;
            turn.LeaseExpiresAt = null;
            _logger.LogWarning("Turn {MessageId} lease expired with unknown provider usage; outcome {Outcome}", messageId, outcome);
            return outcome;
        }, cancellationToken);
    }

    private int Charge(BusinessObject.Entities.User user, int tokens, Guid messageId)
    {
        // Provider overrun beyond the remaining balance is logged, never stored as a negative balance.
        var charged = Math.Min(user.TokenBalance, Math.Max(0, tokens));
        if (charged < tokens)
        {
            _logger.LogWarning(
                "Turn {MessageId} used {Tokens} tokens but user {UserId} had {Balance} left",
                messageId, tokens, user.Id, user.TokenBalance);
        }

        user.TokenBalance -= charged;
        return charged;
    }

    private enum ExpireOutcome
    {
        Skipped,
        Released,
        Charged
    }
}
