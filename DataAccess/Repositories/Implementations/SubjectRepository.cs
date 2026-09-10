using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class SubjectRepository : ISubjectRepository
{
    private readonly ChatAIWebDbContext _context;

    public SubjectRepository(ChatAIWebDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<Subject>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        return await BuildSubjectQuery()
            .Where(subject => !subject.IsDeleted)
            .OrderBy(subject => subject.SubjectCode)
            .ThenBy(subject => subject.SubjectName)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Subject>> GetAllIncludingDeletedAsync(CancellationToken cancellationToken = default)
    {
        return await BuildSubjectQuery()
            .OrderBy(subject => subject.IsDeleted)
            .ThenBy(subject => subject.SubjectCode)
            .ThenBy(subject => subject.SubjectName)
            .ToListAsync(cancellationToken);
    }

    private IQueryable<Subject> BuildSubjectQuery()
    {
        return _context.Subjects
            .AsNoTracking()
            .Include(s => s.Documents)
            .Include(s => s.CreatedByNavigation)
            .Include(s => s.DeletedByNavigation)
            .Include(s => s.SubjectEnrollments)
                .ThenInclude(e => e.User)
            .Include(s => s.ChatSessions);
    }

    public async Task<IReadOnlyList<Subject>> GetUploadableByTeacherAsync(
        int teacherId,
        CancellationToken cancellationToken = default)
    {
        return await _context.Subjects
            .AsNoTracking()
            .Include(s => s.Documents)
            .Include(s => s.CreatedByNavigation)
            .Include(s => s.SubjectEnrollments)
            .Include(s => s.ChatSessions)
            .Where(subject => !subject.IsDeleted)
            .Where(subject =>
                subject.CreatedBy == teacherId
                || subject.SubjectEnrollments.Any(enrollment =>
                    enrollment.UserId == teacherId
                    && enrollment.RoleInClass == "Teacher"))
            .OrderBy(subject => subject.SubjectCode)
            .ThenBy(subject => subject.SubjectName)
            .ToListAsync(cancellationToken);
    }

    public async Task<Subject?> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        return await BuildTrackedSubjectQuery()
            .FirstOrDefaultAsync(s => s.Id == id && !s.IsDeleted, cancellationToken);
    }

    public async Task<Subject?> GetByIdIncludingDeletedAsync(int id, CancellationToken cancellationToken = default)
    {
        return await BuildTrackedSubjectQuery()
            .FirstOrDefaultAsync(s => s.Id == id, cancellationToken);
    }

    private IQueryable<Subject> BuildTrackedSubjectQuery()
    {
        return _context.Subjects
            .Include(s => s.Documents)
            .Include(s => s.CreatedByNavigation)
            .Include(s => s.DeletedByNavigation)
            .Include(s => s.SubjectEnrollments)
                .ThenInclude(e => e.User);
    }

    public async Task AddAsync(Subject subject, CancellationToken cancellationToken = default)
    {
        await _context.Subjects.AddAsync(subject, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task AddEnrollmentAsync(
        SubjectEnrollment enrollment,
        CancellationToken cancellationToken = default)
    {
        await _context.SubjectEnrollments.AddAsync(enrollment, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task AddOrUpdateEnrollmentAsync(
        int subjectId,
        int userId,
        string roleInClass,
        CancellationToken cancellationToken = default)
    {
        var enrollment = await _context.SubjectEnrollments.FirstOrDefaultAsync(
            item => item.SubjectId == subjectId && item.UserId == userId,
            cancellationToken);

        if (enrollment is null)
        {
            await _context.SubjectEnrollments.AddAsync(
                new SubjectEnrollment
                {
                    SubjectId = subjectId,
                    UserId = userId,
                    RoleInClass = roleInClass,
                    CreatedAt = DateTime.UtcNow
                },
                cancellationToken);
        }
        else
        {
            enrollment.RoleInClass = roleInClass;
        }

        await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task DeleteEnrollmentAsync(
        int enrollmentId,
        CancellationToken cancellationToken = default)
    {
        var enrollment = await _context.SubjectEnrollments.FirstOrDefaultAsync(
            item => item.Id == enrollmentId,
            cancellationToken);

        if (enrollment is null)
        {
            return;
        }

        _context.SubjectEnrollments.Remove(enrollment);
        await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task UpdateAsync(Subject subject, CancellationToken cancellationToken = default)
    {
        _context.Subjects.Update(subject);
        await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task SoftDeleteAsync(
        Subject subject,
        int deletedBy,
        string? reason,
        CancellationToken cancellationToken = default)
    {
        subject.IsDeleted = true;
        subject.DeletedAt = DateTime.UtcNow;
        subject.DeletedBy = deletedBy;
        subject.DeleteReason = string.IsNullOrWhiteSpace(reason) ? null : reason.Trim();
        subject.UpdatedAt = DateTime.UtcNow;
        _context.Subjects.Update(subject);
        await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task RestoreAsync(Subject subject, CancellationToken cancellationToken = default)
    {
        subject.IsDeleted = false;
        subject.DeletedAt = null;
        subject.DeletedBy = null;
        subject.DeleteReason = null;
        subject.UpdatedAt = DateTime.UtcNow;
        _context.Subjects.Update(subject);
        await _context.SaveChangesAsync(cancellationToken);
    }
}
