using System.Data;

namespace DataAccess.Repositories.Interfaces;

// Multi-step writes that must commit together. Runs inside the SQL Server execution strategy,
// so the operation may be re-run on a transient failure and must not rely on earlier tracked changes.
public interface IUnitOfWork
{
    Task<T> ExecuteInTransactionAsync<T>(
        Func<CancellationToken, Task<T>> operation,
        IsolationLevel isolationLevel = IsolationLevel.ReadCommitted,
        CancellationToken cancellationToken = default);
}
