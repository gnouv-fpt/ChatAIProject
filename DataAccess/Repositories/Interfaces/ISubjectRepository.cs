using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface ISubjectRepository
{
    Task<IReadOnlyList<Subject>> GetAllAsync(CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Subject>> GetAllIncludingDeletedAsync(CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Subject>> GetUploadableByTeacherAsync(
        int teacherId,
        CancellationToken cancellationToken = default);

    Task<Subject?> GetByIdAsync(int id, CancellationToken cancellationToken = default);

    Task<Subject?> GetByIdIncludingDeletedAsync(int id, CancellationToken cancellationToken = default);

    Task AddAsync(Subject subject, CancellationToken cancellationToken = default);

    Task AddEnrollmentAsync(SubjectEnrollment enrollment, CancellationToken cancellationToken = default);

    Task AddOrUpdateEnrollmentAsync(
        int subjectId,
        int userId,
        string roleInClass,
        CancellationToken cancellationToken = default);

    Task DeleteEnrollmentAsync(
        int enrollmentId,
        CancellationToken cancellationToken = default);

    Task UpdateAsync(Subject subject, CancellationToken cancellationToken = default);

    Task SoftDeleteAsync(
        Subject subject,
        int deletedBy,
        string? reason,
        CancellationToken cancellationToken = default);

    Task RestoreAsync(Subject subject, CancellationToken cancellationToken = default);
}
