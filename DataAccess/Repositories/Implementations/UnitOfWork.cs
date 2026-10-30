using System.Data;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public class UnitOfWork : IUnitOfWork
{
    private readonly ChatAIWebDbContext _context;

    public UnitOfWork(ChatAIWebDbContext context)
    {
        _context = context;
    }

    public Task<T> ExecuteInTransactionAsync<T>(
        Func<CancellationToken, Task<T>> operation,
        IsolationLevel isolationLevel = IsolationLevel.ReadCommitted,
        CancellationToken cancellationToken = default)
    {
        return _context.Database.CreateExecutionStrategy().ExecuteAsync(async () =>
        {
            // A retry must reload entities rather than reuse changes from the rolled-back attempt.
            _context.ChangeTracker.Clear();
            await using var transaction = await _context.Database.BeginTransactionAsync(isolationLevel, cancellationToken);
            var result = await operation(cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return result;
        });
    }
}
